use serde::{Deserialize, Serialize};
use std::fmt;
use std::result;

/// built-in functions
pub static TURTLE_BUILTIN_FUNCTIONS: &[&str] = &[
    "builtin", "alias", "print", "input", "len", "which", "whereis", "cd", "exit", "help",
];

/// keywords
pub static TURTLE_KEYWORDS: &[&str] = &[
    "if", "else", "then", "while", "for", "fn", "return", "let", // "true", "false",
];

/// parser struct
#[derive(Debug, Clone)]
struct TurtleParser {
    parsed: Vec<crate::types::TurtleToken>,
    unknown: Vec<crate::types::TurtleToken>,
    current: usize,
    pos: usize,
}

/// parser implementation
impl TurtleParser {
    /// creates a new TurtleParser
    pub fn new(tokens: Vec<crate::types::TurtleToken>) -> Self {
        TurtleParser {
            parsed: tokens,
            current: 0,
            pos: 0,
            unknown: Vec::new(),
        }
    }

    /// peek at the current token
    pub fn peek(&self) -> &crate::types::TurtleToken {
        self.parsed
            .get(self.pos)
            .unwrap_or(&crate::types::TurtleToken::Eof)
    }

    /// get the next token
    pub fn next(&mut self) -> &crate::types::TurtleToken {
        let tok = self
            .parsed
            .get(self.pos)
            .unwrap_or(&crate::types::TurtleToken::Eof);
        self.pos += 1;
        tok
    }

    /// skip whitespace tokens (space, tab, newline)
    fn skip_whitespace(&mut self) {
        while matches!(
            self.peek(),
            crate::types::TurtleToken::Space
                | crate::types::TurtleToken::Tab
                | crate::types::TurtleToken::Newline
        ) {
            self.next();
        }
    }

    /// parse literal values (Numbers, Strings, Booleans)
    fn parse_literal(&mut self) -> Option<crate::types::TurtleExpression> {
        match self.next() {
            crate::types::TurtleToken::Number(n) => {
                Some(crate::types::TurtleExpression::Number(*n))
            }
            crate::types::TurtleToken::String(s) => {
                Some(crate::types::TurtleExpression::String(s.clone()))
            }
            crate::types::TurtleToken::Boolean(b) => {
                Some(crate::types::TurtleExpression::Boolean(*b))
            }
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
    fn parse_unary(&mut self) -> Option<crate::types::TurtleExpression> {
        self.skip_whitespace();
        if let crate::types::TurtleToken::Operator(op) = self.peek() {
            if op == "-" || op == "!" || op == "~" {
                let op = op.clone();
                self.next(); // consume operator
                self.skip_whitespace();
                if let Some(expr) = self.parse_expr() {
                    return Some(crate::types::TurtleExpression::UnaryOperation {
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
        left: crate::types::TurtleExpression,
    ) -> Option<crate::types::TurtleExpression> {
        if let crate::types::TurtleToken::Operator(op) = self.peek() {
            let op = op.clone();
            self.next(); // consume operator

            if let Some(right) = self.parse_expr() {
                return Some(crate::types::TurtleExpression::BinaryOperation {
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

    ///parse function definitions
    /// ```
    /// code my_function(arg) { print(arg); })
    /// ``````
    fn parse_function_def(&mut self) -> Option<crate::types::TurtleExpression> {
        self.skip_whitespace();
        if let crate::types::TurtleToken::Keyword(k) = self.peek() {
            if k == "fn" {
                self.next(); // consume 'fn'
                self.skip_whitespace();
                let func_name = if let crate::types::TurtleToken::Identifier(name) = self.peek() {
                    let name = name.clone();
                    self.next(); // consume function name
                    self.skip_whitespace();
                    name
                } else {
                    return None; // expected function name
                };

                // parse parameters
                if let crate::types::TurtleToken::ParenOpen = self.peek() {
                    self.next(); // consume '('
                    self.skip_whitespace();
                    let mut params = Vec::new();
                    while !matches!(
                        self.peek(),
                        crate::types::TurtleToken::ParenClose | crate::types::TurtleToken::Eof
                    ) {
                        if let crate::types::TurtleToken::Identifier(param) = self.peek() {
                            params.push(param.clone());
                            self.next(); // consume parameter
                            self.skip_whitespace();
                        }
                        if let crate::types::TurtleToken::Comma = self.peek() {
                            self.next(); // consume ','
                            self.skip_whitespace();
                        } else {
                            break;
                        }
                    }
                    if let crate::types::TurtleToken::ParenClose = self.peek() {
                        self.next(); // consume ')'
                        self.skip_whitespace();
                    } else {
                        return None; // expected ')'
                    }

                    // parse function body
                    if let crate::types::TurtleToken::BraceOpen = self.peek() {
                        self.next(); // consume '{'
                        let mut body = Vec::new();
                        while !matches!(
                            self.peek(),
                            crate::types::TurtleToken::BraceClose | crate::types::TurtleToken::Eof
                        ) {
                            if let Some(expr) = self.parse_expr() {
                                body.push(expr);
                            } else {
                                // skip unknown tokens (?)
                                self.next(); // skip unknown tokens
                                self.skip_whitespace();
                            }
                        }
                        if let crate::types::TurtleToken::BraceClose = self.peek() {
                            self.next(); // consume '}'
                            self.skip_whitespace();
                            return Some(crate::types::TurtleExpression::FunctionDefinition {
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
        expr: crate::types::TurtleExpression,
    ) -> Option<crate::types::TurtleExpression> {
        if let crate::types::TurtleToken::ParenOpen = self.peek() {
            self.next(); // consume '('
            let mut args = Vec::new();
            while !matches!(
                self.peek(),
                crate::types::TurtleToken::ParenClose | crate::types::TurtleToken::Eof
            ) {
                if let Some(arg) = self.parse_expr() {
                    args.push(arg);
                }
                if let crate::types::TurtleToken::Comma = self.peek() {
                    self.next(); // consume ','
                } else {
                    break;
                }
            }
            if let crate::types::TurtleToken::ParenClose = self.peek() {
                self.next(); // consume ')'
                // Use expr as the function (can be Identifier or MemberAccess)
                return Some(crate::types::TurtleExpression::FunctionCall {
                    func: match expr {
                        crate::types::TurtleExpression::Identifier(ref name) => name.clone(),
                        crate::types::TurtleExpression::MemberAccess { .. } => {
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
        expr: crate::types::TurtleExpression,
    ) -> Option<crate::types::TurtleExpression> {
        if let crate::types::TurtleToken::ShellDot = self.peek() {
            self.next(); // consume '.'
            if let crate::types::TurtleToken::Identifier(property) = self.peek() {
                let property = property.clone();
                self.next(); // consume property identifier
                return Some(crate::types::TurtleExpression::MemberAccess {
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
    fn parse_array(&mut self) -> Option<crate::types::TurtleExpression> {
        if let crate::types::TurtleToken::BracketOpen = self.peek() {
            self.next(); // consume '['
            let mut elements = Vec::new();
            while !matches!(
                self.peek(),
                crate::types::TurtleToken::BracketClose | crate::types::TurtleToken::Eof
            ) {
                if let Some(expr) = self.parse_expr() {
                    elements.push(expr);
                }

                if let crate::types::TurtleToken::Comma = self.peek() {
                    self.next(); // consume ','
                } else {
                    break;
                }
            }

            if let crate::types::TurtleToken::BracketClose = self.peek() {
                self.next(); // consume ']'
                return Some(crate::types::TurtleExpression::Array(elements));
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
    fn parse_object(&mut self) -> Option<crate::types::TurtleExpression> {
        if let crate::types::TurtleToken::BraceOpen = self.peek() {
            self.next(); // consume '{'
            let mut properties = Vec::new();
            while !matches!(
                self.peek(),
                crate::types::TurtleToken::BraceClose | crate::types::TurtleToken::Eof
            ) {
                // Get the key as a cloned value
                let key_token = self.next().clone();
                let key = if let crate::types::TurtleToken::Identifier(ref k) = key_token {
                    k.clone()
                } else {
                    return None; // expected identifier key
                };

                if let crate::types::TurtleToken::Colon = self.peek() {
                    self.next(); // consume ':'
                    if let Some(value) = self.parse_expr() {
                        properties.push((key, value));
                    } else {
                        return None; // expected value expression
                    }
                } else {
                    return None; // expected ':'
                }

                if let crate::types::TurtleToken::Comma = self.peek() {
                    self.next(); // consume ','
                } else {
                    break;
                }
            }
            if let crate::types::TurtleToken::BraceClose = self.peek() {
                self.next(); // consume '}'
                return Some(crate::types::TurtleExpression::Object(properties));
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
    fn parse_assignment(&mut self) -> Option<crate::types::TurtleExpression> {
        self.skip_whitespace();
        if let crate::types::TurtleToken::Identifier(name) = self.peek() {
            let name = name.clone();
            self.next(); // consume identifier
            self.skip_whitespace();

            if let crate::types::TurtleToken::Operator(op) = self.peek() {
                if op == "=" {
                    self.next(); // consume '='
                    self.skip_whitespace();
                    if let Some(value) = self.parse_expr() {
                        return Some(crate::types::TurtleExpression::Assignment {
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
        None
    }

    /// parse primitive expressions
    ///
    /// 1
    /// "hello"
    /// [1, 2, 3]
    fn parse_primary(&mut self) -> Option<crate::types::TurtleExpression> {
        // Parse the initial literal, identifier, array, or object
        let mut expr = match self.peek() {
            // literals
            crate::types::TurtleToken::Number(_)
            | crate::types::TurtleToken::String(_)
            | crate::types::TurtleToken::Boolean(_) => self.parse_literal(),
            // arrays & objects
            crate::types::TurtleToken::BracketOpen => self.parse_array(),
            crate::types::TurtleToken::BraceOpen => self.parse_object(),
            // identifiers
            crate::types::TurtleToken::Identifier(name) => {
                let ident = name.clone();
                self.next(); // consume identifier
                Some(crate::types::TurtleExpression::Identifier(ident))
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

    fn parse_command(&mut self) -> Option<crate::types::TurtleExpression> {
        if let crate::types::TurtleToken::Identifier(cmd) = self.peek() {
            let cmd = cmd.clone();
            if !crate::utils::is_command(&cmd) {
                return None;
            }
            self.next(); // consume command identifier

            let mut args = String::new();
            while !matches!(
                self.peek(),
                crate::types::TurtleToken::Eof | crate::types::TurtleToken::Semicolon
            ) {
                match self.peek() {
                    crate::types::TurtleToken::Space
                    | crate::types::TurtleToken::Tab
                    | crate::types::TurtleToken::Newline => {
                        args.push(' ');
                        self.next(); // consume whitespace
                    }
                    crate::types::TurtleToken::String(s) => {
                        args.push_str(&format!("\"{}\"", s));
                        self.next(); // consume string
                    }
                    crate::types::TurtleToken::Number(n) => {
                        args.push_str(&n.to_string());
                        self.next(); // consume number
                    }
                    crate::types::TurtleToken::Identifier(id) => {
                        args.push_str(id);
                        self.next(); // consume identifier
                    }
                    crate::types::TurtleToken::Operator(op) => {
                        args.push_str(op);
                        self.next(); // consume operator
                    }
                    &crate::types::TurtleToken::ShellDot => {
                        args.push('.');
                        self.next(); // consume dot
                    }
                    &crate::types::TurtleToken::ShellDoubleDot => {
                        args.push_str("..");
                        self.next(); // consume double dot
                    }
                    &crate::types::TurtleToken::BracketOpen => {
                        args.push('[');
                        self.next(); // consume '['
                    }
                    &crate::types::TurtleToken::BracketClose => {
                        args.push(']');
                        self.next(); // consume ']'
                    }
                    &crate::types::TurtleToken::ParenOpen => {
                        args.push('(');
                        self.next(); // consume '('
                    }
                    &crate::types::TurtleToken::ParenClose => {
                        args.push(')');
                        self.next(); // consume ')'
                    }
                    &crate::types::TurtleToken::BraceOpen => {
                        args.push('{');
                        self.next(); // consume '{'
                    }
                    &crate::types::TurtleToken::BraceClose => {
                        args.push('}');
                        self.next(); // consume '}'
                    }
                    &crate::types::TurtleToken::Comma => {
                        args.push(',');
                        self.next(); // consume ','
                    }
                    _ => {
                        self.next(); // consume unknown token
                    }
                }
            }

            if let crate::types::TurtleToken::Semicolon = self.peek() {
                self.next(); // consume ';'
            }
            return Some(crate::types::TurtleExpression::ShellCommand {
                name: cmd,
                args: args.trim().to_string(),
            });
        }
        None
    }

    /// implements parsing rules to build TurtleExpression AST
    pub fn parse_expr(&mut self) -> Option<crate::types::TurtleExpression> {
        // parse shell commands
        if let Some(command) = self.parse_command() {
            return Some(command);
        }
        // TODO: implement operator precedence and associativity here
        let mut expr = self.parse_primary();

        if let Some(func_def) = self.parse_function_def() {
            return Some(func_def);
        }

        // TODO: fix assignment parsing
        if let Some(assignment) = self.parse_assignment() {
            return Some(assignment);
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
        while let Some(crate::types::TurtleToken::Operator(_)) = self.peek().clone().into() {
            if let Some(left) = expr {
                expr = self.parse_binary(left);
            } else {
                break;
            }
        }

        expr
    }
}

#[derive(Debug, Clone)]
pub struct TurtleInterpreter {
    counter: usize,
    tokens: Vec<crate::types::TurtleToken>, // parser: Option<TurtleParser>,
}

impl TurtleInterpreter {
    /// create a new TurtleInterpreter
    pub fn new() -> Self {
        TurtleInterpreter {
            counter: 0,
            tokens: Vec::new(),
        }
    }

    /// tokenize primitive tokens from input string, e.g., identifiers, numbers, strings, operators
    pub fn tokenize_primitives(&mut self, input: &str) -> Vec<crate::types::TurtleToken> {
        let mut tokens = Vec::new();
        let mut chars = input.chars().peekable();
        while let Some(&c) = chars.peek() {
            match c {
                // handle ( )
                // these are used for function calls and grouping expressions
                '(' => {
                    tokens.push(crate::types::TurtleToken::ParenOpen);
                    chars.next();
                }
                ')' => {
                    tokens.push(crate::types::TurtleToken::ParenClose);
                    chars.next();
                }
                '{' => {
                    tokens.push(crate::types::TurtleToken::BraceOpen);
                    chars.next();
                }
                '}' => {
                    tokens.push(crate::types::TurtleToken::BraceClose);
                    chars.next();
                }
                '[' => {
                    tokens.push(crate::types::TurtleToken::BracketOpen);
                    chars.next();
                }
                ']' => {
                    tokens.push(crate::types::TurtleToken::BracketClose);
                    chars.next();
                }
                ':' => {
                    tokens.push(crate::types::TurtleToken::Colon);
                    chars.next();
                }
                ';' => {
                    tokens.push(crate::types::TurtleToken::Semicolon);
                    chars.next();
                }
                '-' => {
                    chars.next();
                    if let Some(&'>') = chars.peek() {
                        tokens.push(crate::types::TurtleToken::Arrow);
                        chars.next();
                    } else {
                        tokens.push(crate::types::TurtleToken::Operator("-".to_string()));
                    }
                }
                ',' => {
                    tokens.push(crate::types::TurtleToken::Comma);
                    chars.next();
                }
                '.' => {
                    // let's handle the case of a double dot '..' for relative paths
                    if let Some(&'.') = chars.peek() {
                        tokens.push(crate::types::TurtleToken::ShellDoubleDot);
                        chars.next();
                    } else {
                        tokens.push(crate::types::TurtleToken::ShellDot);
                    }
                    chars.next();
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
                        tokens.push(crate::types::TurtleToken::Newline);
                    } else if ws.contains('\t') {
                        tokens.push(crate::types::TurtleToken::Tab);
                    } else {
                        tokens.push(crate::types::TurtleToken::Space);
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
                    tokens.push(crate::types::TurtleToken::String(s));
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
                    tokens.push(crate::types::TurtleToken::Number(num.parse().unwrap()))
                }
                // testing a better PATH detection
                _ if c.to_string() == "/" || c.to_string() == "." => {
                    let mut path = String::new();
                    while let Some(&d) = chars.peek() {
                        if d == '/' || d == '.' {
                            path.push(d);
                            chars.next();
                        } else {
                            break;
                        }
                    }
                    println!("Found path: {}", path);
                    tokens.push(crate::types::TurtleToken::Identifier(path.clone()));
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

                    // check for assignment operators

                    // check for boolean literals
                    if TURTLE_KEYWORDS.contains(&identifier.as_str()) {
                        tokens.push(crate::types::TurtleToken::Keyword(identifier));
                        continue;
                    } else if identifier == "True" {
                        tokens.push(crate::types::TurtleToken::Boolean(true));
                    } else if identifier == "False" {
                        tokens.push(crate::types::TurtleToken::Boolean(false));
                    } else {
                        tokens.push(crate::types::TurtleToken::Identifier(identifier));
                    }
                }
                _ if "+-*/=<>&|!".contains(c) => {
                    let mut op = String::new();
                    while let Some(&d) = chars.peek() {
                        if "+-*/=<>&|!".contains(d) {
                            op.push(d);
                            chars.next();
                        } else {
                            break;
                        }
                    }

                    tokens.push(crate::types::TurtleToken::Operator(op));
                }

                _ => {
                    chars.next();
                }
            }
        }

        tokens.push(crate::types::TurtleToken::Eof);
        tokens
    }

    pub fn tokenize_shell_commands(
        &mut self,
        tokens: Vec<crate::types::TurtleToken>,
    ) -> Vec<crate::types::TurtleToken> {
        let mut result: Vec<crate::types::TurtleToken> = Vec::new();
        let mut iter = tokens.into_iter().peekable();

        while let Some(token) = iter.next() {
            match &token {
                crate::types::TurtleToken::ShellCommand { name, .. } => {
                    let mut args = String::new();
                    while let Some(next_token) = iter.peek() {
                        match next_token {
                            crate::types::TurtleToken::Eof
                            | crate::types::TurtleToken::Semicolon => break,

                            // BUG: handle ShellCommands embedded in other shell commands
                            // the name and args need to be extracted properly
                            // and joined
                            // Handle dash-arguments: -ah, -l, etc.
                            crate::types::TurtleToken::Operator(op) if op == "-" => {
                                let mut arg = String::from("-");
                                iter.next(); // consume '-'
                                // Concatenate following identifiers (e.g., "ah" in "-ah")
                                while let Some(crate::types::TurtleToken::Identifier(s)) =
                                    iter.peek()
                                {
                                    arg.push_str(s);
                                    iter.next();
                                }
                                if !args.is_empty() {
                                    args.push(' ');
                                }
                                args.push_str(&arg);
                            }

                            // Handle paths: /Users, ./foo, ../bar
                            crate::types::TurtleToken::Operator(op) if op == "/" || op == "." => {
                                let mut path = String::new();
                                // Collect all consecutive Operator/Identifier tokens
                                while let Some(tok) = iter.peek() {
                                    match tok {
                                        crate::types::TurtleToken::Operator(op)
                                            if op == "/" || op == "." =>
                                        {
                                            path.push_str(op);
                                            iter.next();
                                        }
                                        crate::types::TurtleToken::Identifier(seg) => {
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
                            crate::types::TurtleToken::String(s) => {
                                if !args.is_empty() {
                                    args.push(' ');
                                }
                                args.push('"');
                                args.push_str(s);
                                args.push('"');
                                iter.next();
                            }

                            // Handle numbers
                            crate::types::TurtleToken::Number(n) => {
                                if !args.is_empty() {
                                    args.push(' ');
                                }
                                args.push_str(&n.to_string());
                                iter.next();
                            }

                            // Handle identifiers (not part of dash-args or paths)
                            crate::types::TurtleToken::Identifier(s) => {
                                if !args.is_empty() {
                                    args.push(' ');
                                }
                                args.push_str(s);
                                iter.next();
                            }

                            // Handle other operators (e.g., dots)
                            crate::types::TurtleToken::Operator(op) => {
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
                    result.push(crate::types::TurtleToken::ShellCommand {
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
        tokens: Vec<crate::types::TurtleToken>,
    ) -> Vec<crate::types::TurtleToken> {
        let mut result: Vec<crate::types::TurtleToken> = Vec::new();
        let mut iter = tokens.into_iter().peekable();

        while let Some(token) = iter.next() {
            match &token {
                crate::types::TurtleToken::Builtin { name, args } => {
                    let mut args = Vec::new();
                    while let Some(next_token) = iter.peek() {
                        match next_token {
                            crate::types::TurtleToken::Eof
                            | crate::types::TurtleToken::Semicolon => break,

                            crate::types::TurtleToken::Operator(op) if op == "-" => {
                                iter.next(); // consume first '-'
                                // Handles long arg and their values
                                if let Some(crate::types::TurtleToken::Operator(op2)) = iter.peek()
                                {
                                    if op2 == "-" {
                                        iter.next(); // consume second '-'
                                        if let Some(crate::types::TurtleToken::Identifier(name)) =
                                            iter.peek()
                                        {
                                            let name = name.clone();
                                            iter.next(); // consume builtin name
                                            let mut values = Vec::new();
                                            // Optionally, collect values after long arg
                                            while let Some(val_token) = iter.peek() {
                                                match val_token {
                                                    crate::types::TurtleToken::String(_)
                                                    | crate::types::TurtleToken::Identifier(_) => {
                                                        values.push(iter.next().unwrap());
                                                    }
                                                    _ => break,
                                                }
                                            }
                                            args.push(crate::types::TurtleToken::ShellLongArg {
                                                name,
                                                values,
                                            });
                                            continue;
                                        }
                                    }
                                }
                                // Handles short arg and their values
                                if let Some(crate::types::TurtleToken::Identifier(name)) =
                                    iter.peek()
                                {
                                    let name = name.clone();
                                    iter.next(); // consume builtin name
                                    let mut values = Vec::new();
                                    // Optionally, collect values after short arg
                                    while let Some(val_token) = iter.peek() {
                                        match val_token {
                                            crate::types::TurtleToken::String(_)
                                            | crate::types::TurtleToken::Identifier(_) => {
                                                if let crate::types::TurtleToken::Operator(op) =
                                                    val_token
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
                                    args.push(crate::types::TurtleToken::ShellShortArg {
                                        name,
                                        values,
                                    });
                                    continue;
                                }

                                // If no valid arg name follows '-', treat as normal arg
                                // handle path like identifiers
                                // TODO - handle ../ and ./ path variants
                            }

                            // Handle absolute path args: /foo/bar
                            crate::types::TurtleToken::Operator(op) if op == "/" => {
                                let mut path = String::from("/");
                                iter.next(); // consume '/'
                                while let Some(next_seg) = iter.peek() {
                                    match next_seg {
                                        crate::types::TurtleToken::Identifier(seg) => {
                                            if path != "/" {
                                                path.push('/');
                                            }
                                            path.push_str(seg);
                                            iter.next(); // consume segment
                                        }
                                        crate::types::TurtleToken::Operator(op2) if op2 == "/" => {
                                            path.push('/');
                                            iter.next(); // consume '/'
                                        }
                                        crate::types::TurtleToken::Number(n) => {
                                            path.push_str(&n.to_string());
                                            iter.next(); // consume segment
                                        }
                                        crate::types::TurtleToken::String(s) => {
                                            path.push_str(s);
                                            iter.next(); // consume segment
                                        }
                                        crate::types::TurtleToken::Eof
                                        | crate::types::TurtleToken::Semicolon => break,
                                        crate::types::TurtleToken::Operator(op) if op == "-" => {
                                            break;
                                        }
                                        _ => break,
                                    }
                                }
                                args.push(crate::types::TurtleToken::ShellDirectory {
                                    segments: path.split('/').map(|s| s.to_string()).collect(),
                                });
                                continue;
                            }

                            // Handle relative path args: ./foo/bar
                            crate::types::TurtleToken::Operator(op) if op == "." => {
                                let mut path = String::from(".");
                                iter.next(); // consume '.'
                                if let Some(crate::types::TurtleToken::Operator(op2)) = iter.peek()
                                {
                                    if op2 == "/" {
                                        path.push('/');
                                        iter.next(); // consume '/'
                                        while let Some(next_seg) = iter.peek() {
                                            match next_seg {
                                                crate::types::TurtleToken::Identifier(seg) => {
                                                    if !path.ends_with('/') {
                                                        path.push('/');
                                                    }
                                                    path.push_str(seg);
                                                    iter.next(); // consume segment
                                                }
                                                crate::types::TurtleToken::Operator(op3)
                                                    if op3 == "/" =>
                                                {
                                                    path.push('/');
                                                    iter.next(); // consume '/'
                                                }
                                                _ => break,
                                            }
                                        }
                                        args.push(crate::types::TurtleToken::ShellDirectory {
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
                            crate::types::TurtleToken::Identifier(arg) => {
                                args.push(crate::types::TurtleToken::ShellArg {
                                    name: arg.clone(),
                                });
                                iter.next(); // consume arg
                            }

                            _ => {
                                args.push(iter.next().unwrap());
                            }
                        }
                    }
                    result.push(crate::types::TurtleToken::Builtin {
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

    /// full tokenization pipeline
    pub fn tokenize(&mut self, input: &str) -> Vec<crate::types::TurtleToken> {
        let tokens = Self::tokenize_primitives(self, input);
        let tokens: Vec<crate::types::TurtleToken> = Self::tokenize_builtin_functions(self, tokens);
        // let tokens = Self::tokenize_shell_commands(self, tokens);
        self.tokens = tokens.clone();
        self.counter += 1;
        tokens
    }

    pub fn interpret(&mut self) -> Option<crate::types::TurtleExpression> {
        let tokens = self.tokens.clone();
        let mut parser = TurtleParser::new(tokens);
        parser.parse_expr()
    }
}
