/// built-in functions
pub static BUILTINS: &[&str] = &[
    "builtin", "alias", "print", "input", "len", "which", "whereis", "cd", "exit", "help",
];

/// keywords
static KEYWORDS: &[&str] = &[
    "if", "else", "then", "while", "for", "fn", "return", "let", "true", "false",
];

/// parse tokens into AST
#[derive(Debug, Clone)]
struct Parser {
    env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    vars: std::sync::Arc<
        std::sync::Mutex<std::collections::HashMap<String, crate::types::Expressions>>,
    >,
    /// built-in function names
    builtins: Vec<String>,
    /// parsed tokens
    parsed: Vec<crate::types::Token>,
    /// current position in tokens
    pos: usize,
}

/// parser implementation
impl Parser {
    fn get_operator_precedence(&self, op: &str) -> u8 {
        match op {
            "*" | "/" | "%" => 2,
            "+" | "-" => 1,
            _ => 0,
        }
    }
    /// creates a new TurtleParser
    pub fn new(
        tokens: Vec<crate::types::Token>,
        builtins: Vec<String>,
        env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        vars: std::sync::Arc<
            std::sync::Mutex<std::collections::HashMap<String, crate::types::Expressions>>,
        >,
    ) -> Self {
        Parser {
            parsed: tokens,
            pos: 0,
            builtins,
            env,
            aliases,
            vars,
        }
    }

    /// peek at the current token
    pub fn peek(&self) -> &crate::types::Token {
        self.parsed
            .get(self.pos)
            .unwrap_or(&crate::types::Token::Eof)
    }

    /// get the next token
    pub fn next(&mut self) -> &crate::types::Token {
        let tok = self
            .parsed
            .get(self.pos)
            .unwrap_or(&crate::types::Token::Eof);
        self.pos += 1;
        tok
    }

    /// skip whitespace tokens (space, tab, newline)
    fn skip_whitespace(&mut self) {
        while matches!(
            self.peek(),
            crate::types::Token::Space | crate::types::Token::Tab | crate::types::Token::Newline
        ) {
            self.next();
        }
    }

    /// parse literal values (Numbers, Strings, Booleans)
    fn parse_literal(&mut self) -> Option<crate::types::Expressions> {
        match self.next() {
            crate::types::Token::Number(n) => Some(crate::types::Expressions::Number(*n)),
            crate::types::Token::String(s) => Some(crate::types::Expressions::String(s.clone())),
            crate::types::Token::Boolean(b) => Some(crate::types::Expressions::Boolean(*b)),
            _ => None,
        }
    }

    /// parse unary expressions
    ///
    /// ```
    /// -5
    /// !true
    /// ~false
    /// ``````
    fn parse_unary(&mut self) -> Option<crate::types::Expressions> {
        self.skip_whitespace();
        if let crate::types::Token::Operator(op) = self.peek() {
            if op == "-" || op == "!" || op == "~" {
                let op = op.clone();
                self.next(); // consume operator
                self.skip_whitespace();
                if let Some(expr) = self.parse_expr() {
                    return Some(crate::types::Expressions::UnaryOperation {
                        op,
                        expr: Box::new(expr),
                    });
                } else {
                    return None;
                }
            }
        }
        None
    }

    /// parse binary expressions
    ///
    /// **Examples:**
    /// ```
    /// 1 + 2
    ///
    /// x - 3,
    ///
    /// "hello" + " world"
    /// ``````
    fn parse_binary(
        &mut self,
        left: crate::types::Expressions,
    ) -> Option<crate::types::Expressions> {
        if let crate::types::Token::Operator(op) = self.peek() {
            let op = op.clone();
            self.next(); // consume operator

            if let Some(right) = self.parse_expr() {
                return Some(crate::types::Expressions::BinaryOperation {
                    left: Box::new(left),
                    op,
                    right: Box::new(right),
                });
            } else {
                return None;
            }
        }
        None
    }

    fn parse_binary_with_precedence(
        &mut self,
        min_prec: u8,
        mut left: crate::types::Expressions,
    ) -> crate::types::Expressions {
        loop {
            let op = match self.peek() {
                crate::types::Token::Operator(op) => op.clone(),
                _ => break,
            };
            let prec = self.get_operator_precedence(&op);
            if prec < min_prec {
                break;
            }
            self.next(); // consume operator

            // Parse the right-hand side with higher precedence
            let mut right = self
                .parse_primary()
                .unwrap_or(crate::types::Expressions::Number(0.0));
            while let crate::types::Token::Operator(next_op) = self.peek() {
                let next_prec = self.get_operator_precedence(next_op);
                if next_prec > prec {
                    right = self.parse_binary_with_precedence(next_prec, right);
                } else {
                    break;
                }
            }

            left = crate::types::Expressions::BinaryOperation {
                left: Box::new(left),
                op,
                right: Box::new(right),
            };
        }
        left
    }

    ///parse function definitions
    /// ```
    /// code my_function(arg) { print(arg); })
    /// ``````
    fn parse_function_def(&mut self) -> Option<crate::types::Expressions> {
        self.skip_whitespace();
        if let crate::types::Token::Keyword(k) = self.peek() {
            if k == "fn" {
                self.next(); // consume 'fn'
                self.skip_whitespace();
                let func_name = if let crate::types::Token::Identifier(name) = self.peek() {
                    let name = name.clone();
                    self.next(); // consume function name
                    self.skip_whitespace();
                    name
                } else {
                    return None; // expected function name
                };

                // parse parameters
                if let crate::types::Token::ParenOpen = self.peek() {
                    self.next(); // consume '('
                    self.skip_whitespace();
                    let mut params = Vec::new();
                    while !matches!(
                        self.peek(),
                        crate::types::Token::ParenClose | crate::types::Token::Eof
                    ) {
                        if let crate::types::Token::Identifier(param) = self.peek() {
                            params.push(param.clone());
                            self.next(); // consume parameter
                            self.skip_whitespace();
                        }
                        if let crate::types::Token::Comma = self.peek() {
                            self.next(); // consume ','
                            self.skip_whitespace();
                        } else {
                            break;
                        }
                    }
                    if let crate::types::Token::ParenClose = self.peek() {
                        self.next(); // consume ')'
                        self.skip_whitespace();
                    } else {
                        return None; // expected ')'
                    }

                    // parse function body
                    if let crate::types::Token::BraceOpen = self.peek() {
                        self.next(); // consume '{'
                        let mut body = Vec::new();
                        while !matches!(
                            self.peek(),
                            crate::types::Token::BraceClose | crate::types::Token::Eof
                        ) {
                            if let Some(expr) = self.parse_expr() {
                                body.push(expr);
                            } else {
                                // skip unknown tokens (?)
                                self.next(); // skip unknown tokens
                                self.skip_whitespace();
                            }
                        }
                        if let crate::types::Token::BraceClose = self.peek() {
                            self.next(); // consume '}'
                            self.skip_whitespace();
                            return Some(crate::types::Expressions::FunctionDefinition {
                                name: func_name,
                                params,
                                body: Box::new(body),
                            });
                        } else {
                            return None; // expected '}'
                        }
                    }
                }
            }
        }
        None
    }

    /// parse function calls
    /// ```
    /// my_function(...)
    /// ```
    fn parse_function_call(
        &mut self,
        expr: crate::types::Expressions,
    ) -> Option<crate::types::Expressions> {
        if let crate::types::Token::ParenOpen = self.peek() {
            self.next(); // consume '('
            let mut args = Vec::new();
            while !matches!(
                self.peek(),
                crate::types::Token::ParenClose | crate::types::Token::Eof
            ) {
                if let Some(arg) = self.parse_expr() {
                    args.push(arg);
                }
                if let crate::types::Token::Comma = self.peek() {
                    self.next(); // consume ','
                } else {
                    break;
                }
            }
            if let crate::types::Token::ParenClose = self.peek() {
                self.next(); // consume ')'
                // Use expr as the function (can be Identifier or MemberAccess)
                return Some(crate::types::Expressions::FunctionCall {
                    func: match expr {
                        crate::types::Expressions::Identifier(ref name) => name.clone(),
                        crate::types::Expressions::MemberAccess { .. } => {
                            format!("{:?}", expr)
                        } // Or handle as needed
                        _ => return None,
                    },
                    args,
                });
            }
        }
        None
    }

    /// parse member access
    /// ```
    /// object.property
    /// ```
    fn parse_member_access(
        &mut self,
        expr: crate::types::Expressions,
    ) -> Option<crate::types::Expressions> {
        if let crate::types::Token::ShellDot = self.peek() {
            self.next(); // consume '.'
            if let crate::types::Token::Identifier(property) = self.peek() {
                let property = property.clone();
                self.next(); // consume property identifier
                return Some(crate::types::Expressions::MemberAccess {
                    object: Box::new(expr),
                    property,
                });
            }
        }
        None
    }

    /// parse arrays
    /// ```
    /// [1, 2, 3]
    /// ```
    fn parse_array(&mut self) -> Option<crate::types::Expressions> {
        if let crate::types::Token::BracketOpen = self.peek() {
            self.next(); // consume '['
            let mut elements = Vec::new();
            while !matches!(
                self.peek(),
                crate::types::Token::BracketClose | crate::types::Token::Eof
            ) {
                if let Some(expr) = self.parse_expr() {
                    elements.push(expr);
                }

                if let crate::types::Token::Comma = self.peek() {
                    self.next(); // consume ','
                } else {
                    break;
                }
            }

            if let crate::types::Token::BracketClose = self.peek() {
                self.next(); // consume ']'
                return Some(crate::types::Expressions::Array(elements));
            } else {
                return None; // expected ']'
            }
        }
        None
    }

    /// parse objects
    /// ```
    /// {
    ///     key1: value1,
    ///     key2: value2
    /// }
    /// ```
    fn parse_object(&mut self) -> Option<crate::types::Expressions> {
        if let crate::types::Token::BraceOpen = self.peek() {
            self.next(); // consume '{'
            let mut properties = Vec::new();
            while !matches!(
                self.peek(),
                crate::types::Token::BraceClose | crate::types::Token::Eof
            ) {
                // Get the key as a cloned value
                let key_token = self.next().clone();
                let key = if let crate::types::Token::Identifier(ref k) = key_token {
                    k.clone()
                } else {
                    return None; // expected identifier key
                };

                if let crate::types::Token::Colon = self.peek() {
                    self.next(); // consume ':'
                    if let Some(value) = self.parse_expr() {
                        properties.push((key, value));
                    } else {
                        return None; // expected value expression
                    }
                } else {
                    return None; // expected ':'
                }

                if let crate::types::Token::Comma = self.peek() {
                    self.next(); // consume ','
                } else {
                    break;
                }
            }
            if let crate::types::Token::BraceClose = self.peek() {
                self.next(); // consume '}'
                return Some(crate::types::Expressions::Object(properties));
            } else {
                return None; // expected '}'
            }
        }
        None
    }

    /// parse assignment expressions
    /// ```
    /// let s = "hello";
    ///
    /// let n = 5;
    ///
    /// let f = fn(arg) { print(arg) };
    /// ```
    fn parse_assignment(&mut self) -> Option<crate::types::Expressions> {
        self.skip_whitespace();
        // handle assignments prefixed with the let keyword
        if let crate::types::Token::Keyword(k) = self.peek() {
            if k == "let" {
                self.next(); // consume 'let'
                self.skip_whitespace();
                if let crate::types::Token::Identifier(name) = self.peek() {
                    let name = name.clone();
                    self.next(); // consume identifier
                    self.skip_whitespace();

                    if let crate::types::Token::Operator(op) = self.peek() {
                        if op == "=" {
                            self.next(); // consume '='
                            self.skip_whitespace();
                            if let Some(value) = self.parse_expr() {
                                return Some(crate::types::Expressions::Assignment {
                                    name,
                                    value: Box::new(value),
                                });
                            } else {
                                return None; // expected value expression
                            }
                        } else {
                            return None;
                        }
                    }
                }
            } else {
                return None;
            }
        }

        // handle assignments without the let keyword
        if let crate::types::Token::Identifier(name) = self.peek() {
            let name = name.clone();
            self.next(); // consume identifier
            self.skip_whitespace();

            if let crate::types::Token::Operator(op) = self.peek() {
                if op == "=" {
                    self.next(); // consume '='
                    self.skip_whitespace();
                    if let Some(value) = self.parse_expr() {
                        return Some(crate::types::Expressions::Assignment {
                            name,
                            value: Box::new(value),
                        });
                    } else {
                        return None; // expected value expression
                    }
                } else {
                    return None;
                }
            }
        }

        // parse reassignments without the let keyword
        // if let crate::types::Token::Identifier(name) = self.peek() {
        // }

        None
    }

    /// parse variable access
    ///
    fn parse_variable(&mut self) -> Option<crate::types::Expressions> {
        if let crate::types::Token::Identifier(name) = self.peek() {
            let name = name.clone();
            let vars = self.vars.lock().unwrap();
            if let Some(var) = vars.get(&name) {
                return Some(crate::types::Expressions::TurtleVariable {
                    name: name.clone(),
                    value: Box::new(var.clone()),
                });
            } else {
                return None;
            }
        }
        None
    }
    /// parse primitive expressions
    ///
    /// 1
    /// "hello"
    /// [1, 2, 3]
    fn parse_primary(&mut self) -> Option<crate::types::Expressions> {
        // Parse the initial literal, identifier, array, or object
        let mut expr = match self.peek() {
            // literals
            crate::types::Token::Number(_)
            | crate::types::Token::String(_)
            | crate::types::Token::Boolean(_) => self.parse_literal(),
            // arrays & objects
            crate::types::Token::BracketOpen => self.parse_array(),
            crate::types::Token::BraceOpen => self.parse_object(),
            // identifiers
            crate::types::Token::Identifier(name) => {
                let ident = name.clone();
                self.next(); // consume identifier
                Some(crate::types::Expressions::Identifier(ident))
            }
            _ => None,
        }?;

        // Chain member access and function calls modularly
        loop {
            // Try member access
            if let Some(member_expr) = self.parse_member_access(expr.clone()) {
                expr = member_expr;
                continue;
            }
            // Try function call
            if let Some(call_expr) = self.parse_function_call(expr.clone()) {
                expr = call_expr;
                continue;
            }
            break;
        }

        Some(expr)
    }

    fn parse_environment_variable(&mut self) -> Option<crate::types::Expressions> {
        if let crate::types::Token::Operator(op) = self.peek() {
            if op == "$" {
                self.next(); // consume '$'
                if let crate::types::Token::Identifier(name) = self.peek() {
                    let name = name.clone();
                    self.next(); // consume identifier
                    return Some(crate::types::Expressions::EnvironmentVariable { name });
                }
            }
        }
        None
    }

    // TODO: the
    fn parse_builtin(&mut self) -> Option<crate::types::Expressions> {
        if let crate::types::Token::Identifier(cmd) = self.peek() {
            let cmd = cmd.clone();

            if !self.builtins.contains(&cmd) {
                return None;
            }
            // if !crate::builtin::TurtleBuiltin::get(&cmd).is_some() {
            //     println!("Not a builtin: {}", cmd);
            //     return None;
            // }
            self.next(); // consume builtin identifier

            let mut args = String::new();
            while !matches!(
                self.peek(),
                crate::types::Token::Eof | crate::types::Token::Semicolon
            ) {
                match self.peek() {
                    crate::types::Token::Space
                    | crate::types::Token::Tab
                    | crate::types::Token::Newline => {
                        args.push(' ');
                        self.next(); // consume whitespace
                    }
                    crate::types::Token::String(s) => {
                        args.push_str(&format!("\"{}\"", s));
                        self.next(); // consume string
                    }
                    crate::types::Token::Number(n) => {
                        args.push_str(&n.to_string());
                        self.next(); // consume number
                    }
                    crate::types::Token::Identifier(id) => {
                        args.push_str(id);
                        self.next(); // consume identifier
                    }
                    crate::types::Token::Operator(op) => {
                        args.push_str(op);
                        self.next(); // consume operator
                    }
                    _ => {
                        self.next(); // consume unknown token
                    }
                }
            }

            if let crate::types::Token::Semicolon = self.peek() {
                self.next(); // consume ';'
            }
            return Some(crate::types::Expressions::Builtin {
                name: cmd,
                args: args.trim().to_string(),
            });
        }
        None
    }

    // fn parse_variable
    fn parse_command(&mut self) -> Option<crate::types::Expressions> {
        if let crate::types::Token::Identifier(cmd) = self.peek() {
            let cmd = cmd.clone();
            if !crate::utils::is_command(&cmd) {
                return None;
            }
            self.next(); // consume command identifier

            let mut args = String::new();
            while !matches!(
                self.peek(),
                crate::types::Token::Eof | crate::types::Token::Semicolon
            ) {
                match self.peek() {
                    crate::types::Token::Space
                    | crate::types::Token::Tab
                    | crate::types::Token::Newline => {
                        args.push(' ');
                        self.next(); // consume whitespace
                    }
                    crate::types::Token::String(s) => {
                        args.push_str(&format!("\"{}\"", s));
                        self.next(); // consume string
                    }
                    crate::types::Token::Number(n) => {
                        args.push_str(&n.to_string());
                        self.next(); // consume number
                    }
                    crate::types::Token::Identifier(id) => {
                        args.push_str(id);
                        self.next(); // consume identifier
                    }
                    crate::types::Token::Operator(op) => {
                        args.push_str(op);
                        self.next(); // consume operator
                    }
                    &crate::types::Token::ShellDot => {
                        args.push('.');
                        self.next(); // consume dot
                    }
                    &crate::types::Token::ShellDoubleDot => {
                        args.push_str("..");
                        self.next(); // consume double dot
                    }
                    &crate::types::Token::BracketOpen => {
                        args.push('[');
                        self.next(); // consume '['
                    }
                    &crate::types::Token::BracketClose => {
                        args.push(']');
                        self.next(); // consume ']'
                    }
                    &crate::types::Token::ParenOpen => {
                        args.push('(');
                        self.next(); // consume '('
                    }
                    &crate::types::Token::ParenClose => {
                        args.push(')');
                        self.next(); // consume ')'
                    }
                    &crate::types::Token::BraceOpen => {
                        args.push('{');
                        self.next(); // consume '{'
                    }
                    &crate::types::Token::BraceClose => {
                        args.push('}');
                        self.next(); // consume '}'
                    }
                    &crate::types::Token::Comma => {
                        args.push(',');
                        self.next(); // consume ','
                    }
                    _ => {
                        self.next(); // consume unknown token
                    }
                }
            }

            if let crate::types::Token::Semicolon = self.peek() {
                self.next(); // consume ';'
            }
            return Some(crate::types::Expressions::ShellCommand {
                name: cmd,
                args: args.trim().to_string(),
            });
        }
        None
    }

    /// implements parsing rules to build TurtleExpression AST
    pub fn parse_expr(&mut self) -> Option<crate::types::Expressions> {
        // parse  built-in functions
        if let Some(builtin) = self.parse_builtin() {
            return Some(builtin);
        }
        // parse shell commands
        if let Some(command) = self.parse_command() {
            return Some(command);
        }

        // parse variable access - experimental
        if let Some(var_expr) = self.parse_variable() {
            return Some(var_expr);
        }

        if let Some(assignment) = self.parse_assignment() {
            return Some(assignment);
        }

        // parse environment variables
        if let Some(env_var) = self.parse_environment_variable() {
            return Some(env_var);
        }

        let mut expr = self.parse_primary();

        if let Some(func_def) = self.parse_function_def() {
            return Some(func_def);
        }

        loop {
            if let Some(member_access) = self.parse_member_access(expr.clone()?) {
                expr = Some(member_access);
                continue;
            }
            if let Some(func_call) = self.parse_function_call(expr.clone().unwrap()) {
                expr = Some(func_call);
                continue;
            }
            break;
        }

        if let Some(unary) = self.parse_unary() {
            return Some(unary);
        }

        // parse binary operations (chained)
        while let Some(crate::types::Token::Operator(_)) = self.peek().clone().into() {
            if let Some(left) = expr {
                // expr = self.parse_binary(left);
                expr = Some(self.parse_binary_with_precedence(1, left));
            } else {
                break;
            }
        }

        expr
    }
}

/// tokenizes inputs and transforms them into the turtle AST
#[derive(Debug, Clone)]
pub struct Tokenizer {
    // env: std::sync::Ar
    env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    vars: std::sync::Arc<
        std::sync::Mutex<std::collections::HashMap<String, crate::types::Expressions>>,
    >,
    builtins: Vec<String>,
    counter: usize,
    tokens: Vec<crate::types::Token>, // parser: Option<TurtleParser>,
}

impl Tokenizer {
    /// initialize the interpreter
    pub fn new(
        env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        vars: std::sync::Arc<
            std::sync::Mutex<std::collections::HashMap<String, crate::types::Expressions>>,
        >,
        builtins: Vec<String>,
    ) -> Self {
        Tokenizer {
            env,
            aliases,
            vars,
            builtins,
            counter: 0,
            tokens: Vec::new(),
        }
    }

    /// tokenize primitive tokens from input string, e.g., identifiers, numbers, strings, operators
    pub fn tokenize_primitives(&mut self, input: &str) -> Vec<crate::types::Token> {
        let mut tokens = Vec::new();
        let mut chars = input.chars().peekable();
        while let Some(&c) = chars.peek() {
            match c {
                // handle ( )
                // these are used for function calls and grouping expressions
                '(' => {
                    tokens.push(crate::types::Token::ParenOpen);
                    chars.next();
                }
                ')' => {
                    tokens.push(crate::types::Token::ParenClose);
                    chars.next();
                }
                '{' => {
                    tokens.push(crate::types::Token::BraceOpen);
                    chars.next();
                }
                '}' => {
                    tokens.push(crate::types::Token::BraceClose);
                    chars.next();
                }
                '[' => {
                    tokens.push(crate::types::Token::BracketOpen);
                    chars.next();
                }
                ']' => {
                    tokens.push(crate::types::Token::BracketClose);
                    chars.next();
                }
                ':' => {
                    tokens.push(crate::types::Token::Colon);
                    chars.next();
                }
                ';' => {
                    tokens.push(crate::types::Token::Semicolon);
                    chars.next();
                }
                '-' => {
                    chars.next();
                    if let Some(&'>') = chars.peek() {
                        tokens.push(crate::types::Token::Arrow);
                        chars.next();
                    } else {
                        tokens.push(crate::types::Token::Operator("-".to_string()));
                    }
                }
                ',' => {
                    tokens.push(crate::types::Token::Comma);
                    chars.next();
                }
                '.' => {
                    // let's handle the case of a double dot '..' for relative paths
                    // dots can be parts of an identifier
                    if let Some(next) = chars.clone().nth(1) {
                        if next.is_alphanumeric() || next == '_' {
                            let mut identifier = String::from(".");
                            chars.next(); // consume first '.'
                            while let Some(&d) = chars.peek() {
                                if d.is_alphanumeric() || d == '_' || d == '.' {
                                    identifier.push(d);
                                    chars.next();
                                } else {
                                    break;
                                }
                            }
                            tokens.push(crate::types::Token::Identifier(identifier));
                        } else {
                            // old pattern
                            if let Some('.') = chars.clone().nth(1) {
                                tokens.push(crate::types::Token::ShellDoubleDot);
                                chars.next(); // consume first '.'
                                chars.next(); // consume second '.'/
                            } else {
                                tokens.push(crate::types::Token::ShellDot);
                                chars.next(); // consume first '.'
                            }
                        }
                    } else {
                        tokens.push(crate::types::Token::ShellDot);
                        chars.next(); // <-- Always consume first '.'
                    }
                    // old pattern
                    // if let Some(&'.') = chars.peek() {
                    //     tokens.push(crate::types::Token::ShellDoubleDot);
                    //     chars.next();
                    // } else {
                    //     tokens.push(crate::types::Token::ShellDot);
                    // }
                    // chars.next();
                }
                // include white space handling
                ' ' | '\t' | '\n' => {
                    let mut ws = String::new();
                    while let Some(&d) = chars.peek() {
                        if d == ' ' || d == '\t' || d == '\n' {
                            ws.push(d);
                            chars.next();
                        } else {
                            break;
                        }
                    }
                    if ws.contains('\n') {
                        tokens.push(crate::types::Token::Newline);
                    } else if ws.contains('\t') {
                        tokens.push(crate::types::Token::Tab);
                    } else {
                        tokens.push(crate::types::Token::Space);
                    }
                    // chars.next();
                }
                '"' => {
                    chars.next(); // skip opening quote
                    let mut s = String::new();
                    while let Some(&d) = chars.peek() {
                        if d == '"' {
                            chars.next();
                            break;
                        } else {
                            s.push(d);
                            chars.next();
                        }
                    }
                    tokens.push(crate::types::Token::String(s));
                }
                '0'..='9' => {
                    let mut num = String::new();
                    while let Some(&d) = chars.peek() {
                        if d.is_ascii_digit() {
                            num.push(d);
                            chars.next();
                        } else {
                            break;
                        }
                    }
                    tokens.push(crate::types::Token::Number(num.parse().unwrap()))
                }
                '$' => {
                    tokens.push(crate::types::Token::Operator("$".to_string()));
                    chars.next();
                }
                _ if c.is_alphanumeric()
                    || c == "_".chars().next().unwrap()
                    || c == ".".chars().next().unwrap() =>
                {
                    let mut identifier = String::new();
                    while let Some(&d) = chars.peek() {
                        if d.is_alphanumeric()
                            || d == "_".chars().next().unwrap()
                            || d == ".".chars().next().unwrap()
                        {
                            identifier.push(d);
                            chars.next();
                        } else {
                            break;
                        }
                    }

                    // check for boolean literals
                    if KEYWORDS.contains(&identifier.as_str()) {
                        tokens.push(crate::types::Token::Keyword(identifier));
                        continue;
                    } else if identifier == "True" {
                        tokens.push(crate::types::Token::Boolean(true));
                    } else if identifier == "False" {
                        tokens.push(crate::types::Token::Boolean(false));
                    } else {
                        tokens.push(crate::types::Token::Identifier(identifier));
                    }
                }
                _ if "+-*/=<>&|!^".contains(c) => {
                    let mut op = String::new();
                    while let Some(&d) = chars.peek() {
                        if "+-*/=<>&|!^".contains(d) {
                            op.push(d);
                            chars.next();
                        } else {
                            break;
                        }
                    }

                    tokens.push(crate::types::Token::Operator(op));
                }
                _ => {
                    chars.next();
                }
            }
        }

        tokens.push(crate::types::Token::Eof);
        tokens
    }

    /// tokenize shell commands and their arguments (deprecated)
    #[deprecated]
    pub fn tokenize_shell_commands(
        &mut self,
        tokens: Vec<crate::types::Token>,
    ) -> Vec<crate::types::Token> {
        let mut result: Vec<crate::types::Token> = Vec::new();
        let mut iter = tokens.into_iter().peekable();

        while let Some(token) = iter.next() {
            match &token {
                crate::types::Token::ShellCommand { name, .. } => {
                    let mut args = String::new();
                    while let Some(next_token) = iter.peek() {
                        match next_token {
                            crate::types::Token::Eof | crate::types::Token::Semicolon => break,

                            // BUG: handle ShellCommands embedded in other shell commands
                            // the name and args need to be extracted properly
                            // and joined
                            // Handle dash-arguments: -ah, -l, etc.
                            crate::types::Token::Operator(op) if op == "-" => {
                                let mut arg = String::from("-");
                                iter.next(); // consume '-'
                                // Concatenate following identifiers (e.g., "ah" in "-ah")
                                while let Some(crate::types::Token::Identifier(s)) = iter.peek() {
                                    arg.push_str(s);
                                    iter.next();
                                }
                                if !args.is_empty() {
                                    args.push(' ');
                                }
                                args.push_str(&arg);
                            }

                            // Handle paths: /Users, ./foo, ../bar
                            crate::types::Token::Operator(op) if op == "/" || op == "." => {
                                let mut path = String::new();
                                // Collect all consecutive Operator/Identifier tokens
                                while let Some(tok) = iter.peek() {
                                    match tok {
                                        crate::types::Token::Operator(op)
                                            if op == "/" || op == "." =>
                                        {
                                            path.push_str(op);
                                            iter.next();
                                        }
                                        crate::types::Token::Identifier(seg) => {
                                            path.push_str(seg);
                                            iter.next();
                                        }
                                        _ => break,
                                    }
                                }
                                if !args.is_empty() {
                                    args.push(' ');
                                }
                                args.push_str(&path);
                            }

                            // Handle quoted strings
                            crate::types::Token::String(s) => {
                                if !args.is_empty() {
                                    args.push(' ');
                                }
                                args.push('"');
                                args.push_str(s);
                                args.push('"');
                                iter.next();
                            }

                            // Handle numbers
                            crate::types::Token::Number(n) => {
                                if !args.is_empty() {
                                    args.push(' ');
                                }
                                args.push_str(&n.to_string());
                                iter.next();
                            }

                            // Handle identifiers (not part of dash-args or paths)
                            crate::types::Token::Identifier(s) => {
                                if !args.is_empty() {
                                    args.push(' ');
                                }
                                args.push_str(s);
                                iter.next();
                            }

                            // Handle other operators (e.g., dots)
                            crate::types::Token::Operator(op) => {
                                if !args.is_empty() {
                                    args.push(' ');
                                }
                                args.push_str(op);
                                iter.next();
                            }

                            _ => {
                                iter.next();
                            }
                        }
                    }
                    result.push(crate::types::Token::ShellCommand {
                        name: name.clone(),
                        args,
                    });
                }
                _ => result.push(token),
            }
        }

        result
    }

    /// tokenize built-in function calls and their arguments
    pub fn tokenize_builtin_functions(
        &mut self,
        tokens: Vec<crate::types::Token>,
    ) -> Vec<crate::types::Token> {
        let mut result: Vec<crate::types::Token> = Vec::new();
        let mut iter = tokens.into_iter().peekable();

        while let Some(token) = iter.next() {
            match &token {
                crate::types::Token::Builtin { name, args } => {
                    let mut args = Vec::new();
                    while let Some(next_token) = iter.peek() {
                        match next_token {
                            crate::types::Token::Eof | crate::types::Token::Semicolon => break,

                            crate::types::Token::Operator(op) if op == "-" => {
                                iter.next(); // consume first '-'
                                // Handles long arg and their values
                                if let Some(crate::types::Token::Operator(op2)) = iter.peek() {
                                    if op2 == "-" {
                                        iter.next(); // consume second '-'
                                        if let Some(crate::types::Token::Identifier(name)) =
                                            iter.peek()
                                        {
                                            let name = name.clone();
                                            iter.next(); // consume builtin name
                                            let mut values = Vec::new();
                                            // Optionally, collect values after long arg
                                            while let Some(val_token) = iter.peek() {
                                                match val_token {
                                                    crate::types::Token::String(_)
                                                    | crate::types::Token::Identifier(_) => {
                                                        values.push(iter.next().unwrap());
                                                    }
                                                    _ => break,
                                                }
                                            }
                                            args.push(crate::types::Token::ShellLongArg {
                                                name,
                                                values,
                                            });
                                            continue;
                                        }
                                    }
                                }
                                // Handles short arg and their values
                                if let Some(crate::types::Token::Identifier(name)) = iter.peek() {
                                    let name = name.clone();
                                    iter.next(); // consume builtin name
                                    let mut values = Vec::new();
                                    // Optionally, collect values after short arg
                                    while let Some(val_token) = iter.peek() {
                                        match val_token {
                                            crate::types::Token::String(_)
                                            | crate::types::Token::Identifier(_) => {
                                                if let crate::types::Token::Operator(op) = val_token
                                                {
                                                    if op == "-" {
                                                        break;
                                                    }
                                                }
                                                values.push(iter.next().unwrap());
                                            }
                                            _ => break,
                                        }
                                    }
                                    args.push(crate::types::Token::ShellShortArg { name, values });
                                    continue;
                                }

                                // If no valid arg name follows '-', treat as normal arg
                                // handle path like identifiers
                                // TODO - handle ../ and ./ path variants
                            }

                            // Handle absolute path args: /foo/bar
                            crate::types::Token::Operator(op) if op == "/" => {
                                let mut path = String::from("/");
                                iter.next(); // consume '/'
                                while let Some(next_seg) = iter.peek() {
                                    match next_seg {
                                        crate::types::Token::Identifier(seg) => {
                                            if path != "/" {
                                                path.push('/');
                                            }
                                            path.push_str(seg);
                                            iter.next(); // consume segment
                                        }
                                        crate::types::Token::Operator(op2) if op2 == "/" => {
                                            path.push('/');
                                            iter.next(); // consume '/'
                                        }
                                        crate::types::Token::Number(n) => {
                                            path.push_str(&n.to_string());
                                            iter.next(); // consume segment
                                        }
                                        crate::types::Token::String(s) => {
                                            path.push_str(s);
                                            iter.next(); // consume segment
                                        }
                                        crate::types::Token::Eof
                                        | crate::types::Token::Semicolon => break,
                                        crate::types::Token::Operator(op) if op == "-" => {
                                            break;
                                        }
                                        _ => break,
                                    }
                                }
                                args.push(crate::types::Token::ShellDirectory {
                                    segments: path.split('/').map(|s| s.to_string()).collect(),
                                });
                                continue;
                            }

                            // Handle relative path args: ./foo/bar
                            crate::types::Token::Operator(op) if op == "." => {
                                let mut path = String::from(".");
                                iter.next(); // consume '.'
                                if let Some(crate::types::Token::Operator(op2)) = iter.peek() {
                                    if op2 == "/" {
                                        path.push('/');
                                        iter.next(); // consume '/'
                                        while let Some(next_seg) = iter.peek() {
                                            match next_seg {
                                                crate::types::Token::Identifier(seg) => {
                                                    if !path.ends_with('/') {
                                                        path.push('/');
                                                    }
                                                    path.push_str(seg);
                                                    iter.next(); // consume segment
                                                }
                                                crate::types::Token::Operator(op3)
                                                    if op3 == "/" =>
                                                {
                                                    path.push('/');
                                                    iter.next(); // consume '/'
                                                }
                                                _ => break,
                                            }
                                        }
                                        args.push(crate::types::Token::ShellDirectory {
                                            segments: path
                                                .split('/')
                                                .map(|s| s.to_string())
                                                .collect(),
                                        });
                                        continue;
                                    }
                                }
                            }

                            // Handle relative path args: ../foo/bar
                            crate::types::Token::Identifier(arg) => {
                                args.push(crate::types::Token::ShellArg { name: arg.clone() });
                                iter.next(); // consume arg
                            }

                            _ => {
                                args.push(iter.next().unwrap());
                            }
                        }
                    }
                    result.push(crate::types::Token::Builtin {
                        name: name.clone(),
                        args,
                    });
                }
                _ => {
                    result.push(token);
                }
            }
        }

        result
    }

    /// reset interpreter state
    pub fn reset(&mut self) {
        self.counter = 0;
        self.tokens.clear();
    }

    /// tokenization pipeline
    pub fn tokenize(&mut self, input: &str) -> Vec<crate::types::Token> {
        let tokens = Self::tokenize_primitives(self, input);
        let tokens: Vec<crate::types::Token> = Self::tokenize_builtin_functions(self, tokens);
        self.tokens = tokens.clone();
        self.counter += 1;
        tokens
    }

    pub fn interpret(&mut self) -> Option<crate::types::Expressions> {
        let tokens = self.tokens.clone();
        let mut parser = Parser::new(
            tokens,
            self.builtins.clone(),
            self.env.clone(),
            self.aliases.clone(),
            self.vars.clone(),
        );
        parser.parse_expr()
    }
}
