use clap::Parser;
use crossterm::style::Color;
use notify::Watcher;
use serde::{Deserialize, Serialize};
use std::fmt;

/// Reserved words in Turtle
static KEYWORDS: &[&str] = &[
    "if", "else", "then", "while", "for", "fn", "return", "let", "true", "false",
];

/// interval for threads
pub static DEFAULT_INTERVAL_SECS: u64 = 60;
/// default prompt
pub static DEFAULT_PROMPT: &str = "<+ 🐢 +> ";
/// default continuation prompt
pub static DEFAULT_CONTINUATION_PROMPT: &str = "⏭️ ";
/// default format
pub static DEFAULT_FORMAT: &str = "table";
/// default error prompt
pub static DEFAULT_ERROR_PROMPT: &str = "<<< ❌❌❌ >>>";
/// default history size
pub static DEFAULT_HISTORY_SIZE: usize = 1000;
/// default theme
pub static DEFAULT_THEME: &str = "monokai";
/// default debug
pub static DEFAULT_DEBUG: bool = false;
/// default config
pub static DEFAULT_CONFIG: &str = r#"
# Default Turtle configuration file
debug: false
prompt: "<+ 🐢 +> "
continuation_prompt: "⏭️ "
error_prompt: "<<< ❌❌❌ >>>"
history_size: 1000
theme: "monokai"
"#;

#[test]
fn test_default_config() {
    assert!(DEFAULT_CONFIG.contains("debug: false"));
    assert!(DEFAULT_CONFIG.contains("prompt: \"<+ 🐢 +> \""));
    assert!(DEFAULT_CONFIG.contains("history_size: 1000"));
    assert!(DEFAULT_CONFIG.contains("theme: \"monokai\""));
    // let mut confif
}

/// Turtle AST and parser
#[derive(Debug, Clone)]
struct AbstractSyntaxTree {
    debug: bool,
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

/// Parse Turtle tokens ts into an executable AST expression
impl AbstractSyntaxTree {
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
        debug: bool,
    ) -> Self {
        if debug {
            println!("Creating new AbstractSyntaxTree with tokens: {:?}", tokens);
        }
        AbstractSyntaxTree {
            parsed: tokens,
            pos: 0,
            builtins,
            env,
            aliases,
            vars,
            debug,
        }
    }

    /// peek at the current token
    pub fn peek(&self) -> &crate::types::Token {
        if self.debug {
            println!(
                "peeking at token position {}: {:?}",
                self.pos,
                self.parsed.get(self.pos)
            );
        }
        self.parsed
            .get(self.pos)
            .unwrap_or(&crate::types::Token::Eof)
    }

    /// get the next token
    pub fn next(&mut self) -> &crate::types::Token {
        if self.debug {
            println!(
                "Getting next token at position {}: {:?}",
                self.pos,
                self.parsed.get(self.pos)
            );
        }
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
        if self.debug {
            println!(
                "Parsing expression at token position {}: {:?}",
                self.pos,
                self.peek()
            );
        }
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

/// Tokenize & Interpret Turtle code
#[derive(Debug, Clone)]
pub struct Interpreter {
    debug: bool,
    env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    vars: std::sync::Arc<
        std::sync::Mutex<std::collections::HashMap<String, crate::types::Expressions>>,
    >,
    builtins: Vec<String>,
    counter: usize,
    tokens: Vec<crate::types::Token>, // parser: Option<TurtleParser>,
}

impl Interpreter {
    /// initialize the interpreter
    pub fn new(
        env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        vars: std::sync::Arc<
            std::sync::Mutex<std::collections::HashMap<String, crate::types::Expressions>>,
        >,
        builtins: Vec<String>,
        debug: bool,
    ) -> Self {
        if debug {
            println!("creating new Interpreter");
        }
        Interpreter {
            env,
            aliases,
            vars,
            builtins,
            counter: 0,
            tokens: Vec::new(),
            debug,
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

    /// Tokenize shell commands and args
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

    /// Tokenize built-in function calls and their arguments
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

    /// Tokenization pipeline
    pub fn tokenize(&mut self, input: &str) -> Vec<crate::types::Token> {
        let tokens = Self::tokenize_primitives(self, input);
        let tokens: Vec<crate::types::Token> = Self::tokenize_builtin_functions(self, tokens);
        self.tokens = tokens.clone();
        self.counter += 1;
        tokens
    }

    /// Generate AST from tokens
    pub fn interpret(&mut self) -> Option<crate::types::Expressions> {
        let tokens = self.tokens.clone();
        let mut parser = AbstractSyntaxTree::new(
            tokens,
            self.builtins.clone(),
            self.env.clone(),
            self.aliases.clone(),
            self.vars.clone(),
            self.debug,
        );
        parser.parse_expr()
    }
}

#[test]
fn test_tokenize_primitives() {
    let mut interpreter = Interpreter::new(
        std::sync::Arc::new(std::sync::Mutex::new(std::collections::HashMap::new())),
        std::sync::Arc::new(std::sync::Mutex::new(std::collections::HashMap::new())),
        std::sync::Arc::new(std::sync::Mutex::new(std::collections::HashMap::new())),
        vec![],
        false,
    );
    let input = r#"echo "Hello, World!" -a /path/to/dir"#;
    let tokens = interpreter.tokenize_primitives(input);
    assert_eq!(
        tokens,
        vec![
            crate::types::Token::Identifier("echo".to_string()),
            crate::types::Token::Space,
            crate::types::Token::String("Hello, World!".to_string()),
            crate::types::Token::Space,
            crate::types::Token::Operator("-".to_string()),
            crate::types::Token::Identifier("a".to_string()),
            crate::types::Token::Space,
            crate::types::Token::Operator("/".to_string()),
            crate::types::Token::Identifier("path".to_string()),
            crate::types::Token::Operator("/".to_string()),
            crate::types::Token::Identifier("to".to_string()),
            crate::types::Token::Operator("/".to_string()),
            crate::types::Token::Identifier("dir".to_string()),
            crate::types::Token::Eof,
        ]
    );
}

#[derive(Debug)]
pub struct Shell {
    debug: bool,
    defaults: crate::types::Defaults,
    watcher: Option<notify::RecommendedWatcher>,
    thememanager: crate::types::ThemeManager,
    // pub args: Option<crate::types::Arguments>,
    // pub config: Option<crate::types::Config>,
    pub config: Option<std::sync::Arc<std::sync::Mutex<crate::types::Config>>>,
    pub args: Option<std::sync::Arc<std::sync::Mutex<crate::types::Arguments>>>,

    pub interpreter: crate::types::Interpreter,
    pub context: crate::types::Context,
    pub pid: Option<u32>,
    pub paused: bool,
    pub running: bool,
    // replace events with history manager
    history: std::sync::Arc<std::sync::Mutex<crate::types::History>>,
    events: std::sync::Arc<std::sync::Mutex<Vec<crate::types::Event>>>,
    env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    tokens: Vec<Vec<crate::types::Token>>,
    expressions: Vec<crate::types::Expressions>,
}

impl Shell {
    fn get_readline(&self) -> rustyline::DefaultEditor {
        let config = rustyline::config::Config::builder()
            .edit_mode(rustyline::config::EditMode::Vi)
            .build();
        let rl = rustyline::DefaultEditor::with_config(config);
        rl.unwrap()
    }

    pub fn get_config(args: Option<Arguments>) -> crate::types::Config {
        let defaults = crate::types::Defaults::default();
        let config_path = args
            .as_ref()
            .and_then(|args| args.config_path.as_ref())
            .unwrap_or(&defaults.config_path)
            .clone();
        let config = if std::path::Path::new(config_path.as_str()).exists() {
            crate::types::Config::load(config_path.as_str()).unwrap()
        } else {
            crate::types::Config::loads(&defaults.config).unwrap()
        };
        config
    }

    pub fn new(args: crate::types::Arguments) -> Self {
        let defaults = crate::types::Defaults::default();
        let args = Some(args);

        let config_path = args
            .as_ref()
            .and_then(|args| args.config_path.as_ref())
            .unwrap_or(&defaults.config_path)
            .clone();

        // let config = crate::types::Config::load(config_path.as_str()).unwrap();
        let config = Self::get_config(args.as_ref().map(|a| a.clone()));
        let config = Some(std::sync::Arc::new(std::sync::Mutex::new(config)));

        let debug = args.as_ref().unwrap().debug
            || config
                .as_ref()
                .map(|c| c.lock().unwrap().debug)
                .unwrap_or(false)
            || defaults.debug;
        let mut _aliases_ = std::collections::HashMap::new();

        if let Some(cfg) = &config {
            if let Some(turtle_aliases) = &cfg.lock().unwrap().aliases {
                for (key, value) in turtle_aliases {
                    _aliases_.insert(key.clone(), value.clone());
                }
            }
        }

        let aliases = std::sync::Arc::new(std::sync::Mutex::new(_aliases_));
        let user_env = crate::utils::build_user_environment();
        let env = std::sync::Arc::new(std::sync::Mutex::new(user_env));
        let vars = std::sync::Arc::new(std::sync::Mutex::new(std::collections::HashMap::<
            String,
            crate::types::Expressions,
        >::new()));

        let args = Some(std::sync::Arc::new(std::sync::Mutex::new(args.unwrap())));

        let history_path = args
            .as_ref()
            .and_then(|args| args.lock().unwrap().history_path.clone())
            .unwrap_or(defaults.history_path.clone());

        let mut history = crate::types::History::new(
            Some(history_path.clone()),
            Some(defaults.save_interval),
            debug,
        );

        history.setup();
        let history = std::sync::Arc::new(std::sync::Mutex::new(history));

        let events = history.lock().unwrap().load().unwrap();
        let events = std::sync::Arc::new(std::sync::Mutex::new(events));

        let mut context = crate::types::Context::new(
            env.clone(),
            aliases.clone(),
            vars.clone(),
            events.clone(),
            debug,
        );
        context.setup();
        let mut builtin_names: Vec<String> = Vec::new();
        if let Some(builtins) = &context.builtins {
            let names = builtins.list();
            builtin_names.extend(names);
        }

        let interpreter = crate::types::Interpreter::new(
            env.clone(),
            aliases.clone(),
            vars.clone(),
            builtin_names.clone(),
            debug,
        );

        if debug {
            println!(
                "🐢 Initializing TurtleShell with config: {:?} and args {:?}",
                config, args
            );
        }

        let thememanager = crate::types::ThemeManager::new();

        if debug {
            println!("🐢 TurtleShell initialized");
        }
        Shell {
            debug,
            defaults,
            watcher: None,
            config: config.clone(),
            args,
            thememanager,
            history,
            events,
            env,
            aliases,
            interpreter,
            context,
            pid: None,
            paused: false,
            running: false,
            tokens: Vec::new(),
            expressions: Vec::new(),
        }
    }

    /// Set up the shell
    pub fn setup(&mut self) -> std::collections::HashMap<String, u128> {
        let _start = crate::utils::now();
        self.pid = std::process::id().into();
        self.running = true;
        self.paused = false;
        let _elapsed = _start.elapsed();
        if self.debug {
            println!(
                "🐢 setup completed in {} milliseconds",
                _elapsed.as_millis()
            );
        }
        return std::collections::HashMap::from([("total".into(), _elapsed.as_millis())]);
    }

    // Reload the shell configuration
    // pub fn reload(&mut self) -> crate::types::Config {
    //     self.load_config()
    // }

    /// Start the shell main loop
    pub fn start(&mut self) {
        if self.debug {
            println!("🐢 Starting Turtle Shell...");
        }
        self.setup();

        // get default settings
        let default_config_path = self.defaults.config_path.clone();
        let default_history_path = self.defaults.history_path.clone();
        let default_prompt = self.defaults.prompt.clone();
        let default_theme = self.defaults.theme.clone();

        // lock & process args and config

        let args = self
            .args
            .as_ref()
            .and_then(|a| Some(a.lock().unwrap().clone()));

        let config = self
            .config
            .as_ref()
            .and_then(|c| Some(c.lock().unwrap().clone()));

        let user_prompt = config
            .clone()
            .and_then(|cfg| cfg.prompt)
            .unwrap_or(default_prompt.clone());

        let user_theme = config
            .clone()
            .and_then(|cfg| cfg.theme)
            .unwrap_or(default_theme.clone());

        // --watch-config flag
        if let Some(watch_config) = args.as_ref().and_then(|a| Some(a.watch_config)) {
            let config_path = args
                // .as_ref()
                .and_then(|args| args.config_path)
                .unwrap_or(default_config_path.clone());
            if watch_config {
                if let Some(cfg) = &self.config {
                    match cfg.lock().unwrap().watch(config_path.as_str()) {
                        Ok(watcher) => {
                            self.watcher = Some(watcher);
                            if self.debug {
                                println!("✅ watching config file for changes: {}", config_path);
                            }
                        }
                        Err(e) => {
                            eprintln!("❌ failed to watch config file: {}", e);
                        }
                    }
                } else {
                    eprintln!(
                        "❌ cannot watch config file because it failed to load: {}",
                        config_path
                    );
                }
            }
        }

        let start = crate::utils::now();
        let mut editor = self.get_readline();

        if let Some(list_themes) = self
            .args
            .as_ref()
            .and_then(|a| Some(a.lock().unwrap().list_themes))
        {
            if list_themes {
                self.thememanager.list().iter().for_each(|theme_name| {
                    println!("- {}", theme_name);
                });
                std::process::exit(0);
            }
        }

        self.thememanager
            .apply(&mut std::io::stdout(), &user_theme)
            .ok();

        // get our prompt from the configuration file, or use the default
        let user_prompt = self
            .config
            .as_ref()
            .and_then(|cfg| cfg.lock().unwrap().prompt.clone())
            .unwrap_or(default_prompt.clone());

        let rendered_prompt = user_prompt.clone();
        let mut turtle_prompt = crate::types::Prompt::new(rendered_prompt.as_str());

        if let Some(command) = self
            .args
            .as_ref()
            .and_then(|args| args.lock().unwrap().command.clone())
        // .as_str()
        {
            let tokens = self.interpreter.tokenize(command.as_str());

            let expr = self.interpreter.interpret();
            let result = self.context.eval(expr.clone());
            if let Some(res) = result {
                // res.
                if self.debug {
                    println!("result: {:?}", res);
                }
                // if result.
                std::process::exit(0);
            }
            // exit after executing the command from args
        }

        loop {
            let readline = editor.readline(turtle_prompt.render().as_str());

            // get user input
            let input = match readline {
                Ok(line) => line,
                Err(rustyline::error::ReadlineError::Interrupted) => {
                    println!("^C");
                    continue;
                }
                Err(rustyline::error::ReadlineError::Eof) => {
                    println!("^D");
                    std::process::exit(0);
                    // exit the shell on EOF
                }
                Err(err) => {
                    println!("input error: {:?}", err);
                    break;
                }
            };

            // trim input
            let input = input.trim();

            // skip empty input
            if input.is_empty() {
                continue;
            }

            let tokens = self.interpreter.tokenize(input);
            if self.debug {
                println!("tokens: {:?}", tokens);
            }
            self.tokens.push(tokens.clone());
            let expr = self.interpreter.interpret();

            if self.debug {
                println!("expression: {:?}", expr);
            }

            if expr.is_none() {
                println!("Invalid command or expression");
                continue;
            }

            self.expressions.push(expr.clone().unwrap());
            let result = self.context.eval(expr.clone());
            if let Some(res) = result {
                if self.debug {
                    println!("result: {:?}", res);
                }
            }
        }
        let elapsed = start.elapsed();
        if self.debug {
            println!(
                "🐢 shell main loop exited after {} milliseconds",
                elapsed.as_millis()
            );
        }
    }
}

/// shell default settings
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Defaults {
    pub config: String,
    pub config_path: String,
    pub history_path: String,
    pub prompt: String,
    pub continuation_prompt: String,
    pub error_prompt: String,
    pub history_size: usize,
    pub theme: String,
    pub debug: bool,
    pub save_interval: u64,
    pub format: String,
}

impl Default for Defaults {
    fn default() -> Self {
        let home = dirs::home_dir().unwrap_or_else(|| std::path::PathBuf::from("."));
        let config_path = home.join(".turtlerc.yaml");
        let history_path = home.join(".turtle_history.json");
        Defaults {
            config: DEFAULT_CONFIG.to_string(),
            config_path: config_path.to_string_lossy().to_string(),
            history_path: history_path.to_string_lossy().to_string(),
            prompt: DEFAULT_PROMPT.to_string(),
            continuation_prompt: DEFAULT_CONTINUATION_PROMPT.to_string(),
            error_prompt: DEFAULT_ERROR_PROMPT.to_string(),
            history_size: DEFAULT_HISTORY_SIZE,
            theme: DEFAULT_THEME.to_string(),
            debug: DEFAULT_DEBUG,
            save_interval: DEFAULT_INTERVAL_SECS,
            format: DEFAULT_FORMAT.to_string(),
        }
    }
}

/// shell configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub debug: bool,
    pub prompt: Option<String>,
    pub aliases: Option<std::collections::HashMap<String, String>>,
    pub history_size: Option<usize>,
    pub theme: Option<String>,
}

impl Default for Config {
    fn default() -> Self {
        let defaults = Defaults::default();
        Config {
            debug: defaults.debug,
            prompt: Some(defaults.prompt),
            aliases: None,
            history_size: Some(defaults.history_size),
            theme: Some(defaults.theme),
        }
    }
}

impl Config {
    pub fn load(yaml: &str) -> Option<Self> {
        let expanded_path = if yaml.starts_with("~") {
            if let Some(home) = dirs::home_dir() {
                let without_tilde = yaml.trim_start_matches("~");
                home.join(without_tilde).to_string_lossy().to_string()
            } else {
                yaml.to_string()
            }
        } else {
            yaml.to_string()
        };
        let contents = std::fs::read_to_string(expanded_path).ok()?;
        serde_yaml::from_str::<Config>(&contents).ok()
    }

    pub fn as_mutex(&self) -> std::sync::Arc<std::sync::Mutex<Self>> {
        std::sync::Arc::new(std::sync::Mutex::new(self.clone()))
    }

    pub fn loads(yaml_content: &str) -> Option<Self> {
        serde_yaml::from_str::<Config>(yaml_content).ok()
    }

    pub fn watch(&self, path: &str) -> std::io::Result<notify::RecommendedWatcher> {
        let expanded_path = crate::utils::expand_path(path);
        let (tx, rx) = std::sync::mpsc::channel();
        let mut watcher = notify::recommended_watcher(tx)
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e))?;

        if self.debug {
            println!("Watching config file: {}", expanded_path);
        }

        watcher
            .watch(
                std::path::Path::new(&expanded_path),
                notify::RecursiveMode::NonRecursive,
            )
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e))?;

        std::thread::spawn(move || {
            for res in rx {
                match res {
                    Ok(event) => {
                        println!("config file changed: {:?}", event);
                        Config::load(&expanded_path);
                    }
                    Err(e) => println!("watch error: {:?}", e),
                }
            }
        });

        Ok(watcher)
    }

    pub fn save(&self, path: &str) -> std::io::Result<()> {
        let expanded_path = if path.starts_with("~") {
            if let Some(home) = dirs::home_dir() {
                let without_tilde = path.trim_start_matches("~");
                home.join(without_tilde).to_string_lossy().to_string()
            } else {
                path.to_string()
            }
        } else {
            path.to_string()
        };
        let yaml = serde_yaml::to_string(self).unwrap();
        std::fs::write(expanded_path, yaml)
    }

    pub fn validate(&self) -> bool {
        true
    }
}

#[test]
fn test_config_loads() {
    let yaml_content = r#"
    debug: true
    prompt: ">"
    aliases:
        ll: "ls -la"
    history_size: 1000
    theme: "dark"
    "#;

    let config = Config::loads(yaml_content);
    assert!(config.is_some());
    let config = config.unwrap();
    assert_eq!(config.debug, true);
    assert_eq!(config.prompt, Some(">".into()));
    assert_eq!(
        config.aliases,
        Some(vec![("ll".into(), "ls -la".into())].into_iter().collect())
    );
    assert_eq!(config.history_size, Some(1000));
    assert_eq!(config.theme, Some("dark".into()));
}

#[test]
fn test_config_load() {
    let home = dirs::home_dir().unwrap();
    let test_config_path = home.join(".turtle_test_config.yaml");
    let yaml_content = r#"
    debug: true
    prompt: ">"
    aliases:
        ll: "ls -la"
    history_size: 1000
    theme: "dark"
    "#;
    std::fs::write(&test_config_path, yaml_content).unwrap();

    let config = Config::load(test_config_path.to_str().unwrap());
    assert!(config.is_some());
    let config = config.unwrap();
    assert_eq!(config.debug, true);
    assert_eq!(config.prompt, Some(">".into()));
    assert_eq!(
        config.aliases,
        Some(vec![("ll".into(), "ls -la".into())].into_iter().collect())
    );
    assert_eq!(config.history_size, Some(1000));
    assert_eq!(config.theme, Some("dark".into()));

    std::fs::remove_file(test_config_path).unwrap();
}

/// process arguments for the shell
#[derive(clap::Parser, Clone, Default, Debug, Serialize, Deserialize)]
#[command(name = "turtle", about = "An interpreted Rust shell")]
pub struct Arguments {
    /// enable debugging
    #[arg(short, long, help = "Enable Debugging", default_value_t = false)]
    pub debug: bool,

    /// show version and exit
    #[arg(short, long, help = "Show Version and Exit", default_value_t = false)]
    pub version: bool,

    /// configuration file
    #[arg(long, help = "Config File", default_value = "~/.turtle.yaml")]
    pub config_path: Option<String>,

    /// history file
    #[arg(long, help = "History File", default_value = "~/.turtle_history.json")]
    pub history_path: Option<String>,

    /// command to execute in non-interactive mode
    #[arg(long, help = "Evaluate Command", default_value = None)]
    pub command: Option<String>,

    /// set output format
    #[arg(short, long, help = "Output Format", default_value = "table")]
    pub format: Option<String>,

    /// skip history loading
    #[arg(long, help = "Skip History", default_value_t = false)]
    pub skip_history: bool,

    // skip alias loading
    #[arg(long, help = "Skip Aliases", default_value_t = false)]
    pub skip_aliases: bool,

    /// list available themes
    #[arg(long, help = "List Available Themes", default_value_t = false)]
    pub list_themes: bool,

    /// enable config file watching
    #[arg(long, help = "Watch Config File for Changes", default_value_t = false)]
    pub watch_config: bool,
}

impl Arguments {
    pub fn new() -> Self {
        return Arguments::parse();
    }

    pub fn from() -> Self {
        return Arguments::parse();
    }

    pub fn validate(&self) -> bool {
        true
    }
}

#[test]
fn test_arguments() {
    let args = Arguments::new();
    assert!(args.validate());
}

/// manage shell environment variables
#[derive(Debug, Clone)]
pub struct Environment {
    pub vars: std::collections::HashMap<String, String>,
}

impl Environment {
    pub fn new() -> Self {
        Environment {
            vars: std::collections::HashMap::new(),
        }
    }

    fn default() -> std::collections::HashMap<String, String> {
        let mut details = std::collections::HashMap::new();
        if let Some(username) = users::get_current_username() {
            details.insert("USER".to_string(), username.to_string_lossy().to_string());
        }

        if let Some(home_dir) = dirs::home_dir() {
            details.insert("HOME".to_string(), home_dir.to_string_lossy().to_string());
        }
        return details;
    }

    pub fn setup(&mut self) {
        self.vars = Self::default();
        for (key, value) in std::env::vars() {
            if key.starts_with("TURTLE_") {
                let var_name = key.trim_start_matches("TURTLE_").to_string();
                self.vars.insert(var_name, value);
            }
        }
    }

    pub fn set(&mut self, key: &str, value: &str) {
        self.vars.insert(key.to_string(), value.to_string());
    }

    pub fn unset(&mut self, key: &str) {
        self.vars.remove(key);
    }

    pub fn get(&self, key: &str) -> Option<&String> {
        self.vars.get(key)
    }

    pub fn list(&self) -> Vec<(&String, &String)> {
        self.vars.iter().collect()
    }
}

#[test]
fn test_environment() {
    let mut env = Environment::new();
    env.setup();
    env.set("TEST_VAR", "test_value");
    assert_eq!(env.get("TEST_VAR"), Some(&"test_value".to_string()));
    env.unset("TEST_VAR");
    assert_eq!(env.get("TEST_VAR"), None);
}

/// Theme definition
#[derive(Debug, Clone)]
pub struct Theme {
    pub foreground: Color,
    pub background: Color,
    pub text: Color,
    pub cursor: Color,
    pub selection: Color,
}

/// Theme manager
#[derive(Debug, Clone)]
pub struct ThemeManager {
    pub theme: String,
    pub themes: std::collections::HashMap<String, crate::types::Theme>,
}

impl ThemeManager {
    pub fn new() -> Self {
        let themes = std::collections::HashMap::from([
            (
                "solarized_dark".to_string(),
                crate::types::Theme {
                    foreground: Color::Rgb {
                        r: 131,
                        g: 148,
                        b: 150,
                    },
                    background: Color::Rgb { r: 0, g: 43, b: 54 },
                    text: Color::Rgb {
                        r: 147,
                        g: 161,
                        b: 161,
                    },
                    cursor: Color::Rgb {
                        r: 147,
                        g: 161,
                        b: 161,
                    },
                    selection: Color::Rgb { r: 7, g: 54, b: 66 },
                },
            ),
            (
                "solarized_light".to_string(),
                crate::types::Theme {
                    foreground: Color::Rgb {
                        r: 101,
                        g: 123,
                        b: 131,
                    },
                    background: Color::Rgb {
                        r: 253,
                        g: 246,
                        b: 227,
                    },
                    text: Color::Rgb {
                        r: 101,
                        g: 123,
                        b: 131,
                    },
                    cursor: Color::Rgb {
                        r: 101,
                        g: 123,
                        b: 131,
                    },
                    selection: Color::Rgb {
                        r: 238,
                        g: 232,
                        b: 213,
                    },
                },
            ),
            (
                "monokai".to_string(),
                crate::types::Theme {
                    foreground: Color::Rgb {
                        r: 248,
                        g: 248,
                        b: 242,
                    },
                    background: Color::Rgb {
                        r: 39,
                        g: 40,
                        b: 34,
                    },
                    text: Color::Rgb {
                        r: 248,
                        g: 248,
                        b: 242,
                    },
                    cursor: Color::Rgb {
                        r: 248,
                        g: 248,
                        b: 242,
                    },
                    selection: Color::Rgb {
                        r: 73,
                        g: 72,
                        b: 62,
                    },
                },
            ),
            (
                "catppuccino".to_string(),
                crate::types::Theme {
                    foreground: Color::Rgb {
                        r: 75,
                        g: 56,
                        b: 50,
                    },
                    background: Color::Rgb {
                        r: 241,
                        g: 224,
                        b: 214,
                    },
                    text: Color::Rgb {
                        r: 75,
                        g: 56,
                        b: 50,
                    },
                    cursor: Color::Rgb {
                        r: 75,
                        g: 56,
                        b: 50,
                    },
                    selection: Color::Rgb {
                        r: 224,
                        g: 200,
                        b: 176,
                    },
                },
            ),
        ]);
        ThemeManager {
            theme: "solarized_dark".to_string(),
            themes,
        }
    }

    pub fn list(&self) -> Vec<&String> {
        self.themes.keys().collect()
    }

    pub fn apply<W: std::io::Write>(
        &self,
        writer: &mut W,
        theme_name: &str,
    ) -> std::io::Result<()> {
        let theme = self
            .themes
            .get(theme_name)
            .or_else(|| self.themes.get(DEFAULT_THEME));
        let theme = match theme {
            Some(theme) => theme,
            None => {
                return Err(std::io::Error::new(
                    std::io::ErrorKind::NotFound,
                    "Theme not found",
                ));
            }
        };

        crossterm::execute!(
            writer,
            crossterm::style::ResetColor,
            crossterm::style::SetForegroundColor(theme.foreground),
            crossterm::style::SetBackgroundColor(theme.background),
            crossterm::style::SetStyle(crossterm::style::ContentStyle {
                foreground_color: Some(theme.text),
                background_color: Some(theme.background),
                underline_color: None,
                attributes: crossterm::style::Attributes::default(),
            }),
            // crossterm::style::SetSelectionColor(theme.selection),
        )?;
        Ok(())
    }
}

/// Turtle shell prompt
pub struct Prompt<'a> {
    template: &'a str,
}

impl<'a> Prompt<'a> {
    pub fn new(template: &'a str) -> Self {
        Prompt { template }
    }

    pub fn context(&self) -> PromptContext {
        PromptContext {
            user: whoami::username(),
            host: whoami::fallible::hostname().unwrap_or_else(|_| "?".into()),
            cwd: std::env::current_dir()
                .map(|path| path.display().to_string())
                .unwrap_or_else(|_| "?".to_string()),
            time: chrono::Local::now().format("%H:%M:%S").to_string(),
            turtle: "🐢".into(),
        }
    }

    pub fn render(&mut self) -> String {
        let context = self.context();
        let mut engine = tinytemplate::TinyTemplate::new();
        let template = self.template;
        engine.add_template("prompt", template);
        engine
            .render("prompt", &context)
            .unwrap_or_else(|_| template.to_string())
    }
}

/// Turtle shell prompt context
#[derive(Serialize, Deserialize)]
pub struct PromptContext {
    pub user: String,
    pub host: String,
    pub cwd: String,
    pub time: String,
    pub turtle: String,
}

impl PromptContext {
    pub fn list_fields() -> Vec<&'static str> {
        vec!["user", "host", "cwd", "time", "turtle"]
    }
}

impl fmt::Display for PromptContext {
    // prints the fields available for the prompt as a list
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        let fields = PromptContext::list_fields();
        write!(f, "Available fields: {}", fields.join(", "))
    }
}

impl fmt::Display for Outputs {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Outputs::Table(table) => {
                let mut output = String::new();
                output.push_str(&table.headers.join("\t"));
                output.push('\n');
                for row in &table.data {
                    output.push_str(&row.join("\t"));
                    output.push('\n');
                }
                write!(f, "{}", output)
            }
            Outputs::Json(json) => {
                let json_string =
                    serde_json::to_string_pretty(&json.data).map_err(|_| fmt::Error)?;
                write!(f, "{}", json_string)
            }
            Outputs::Yaml(yaml) => {
                let yaml_string = serde_yaml::to_string(&yaml.data).map_err(|_| fmt::Error)?;
                write!(f, "{}", yaml_string)
            }
            Outputs::Text(text) => {
                write!(f, "{}", text.data)
            }
            Outputs::Ast(ast) => {
                write!(f, "{}", ast.data)
            }
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub enum Outputs {
    Table(OutputCsv),
    Json(OutputJson),
    Yaml(OutputYaml),
    Text(OutputText),
    Ast(OutAst),
}

/// shell output formats
impl Outputs {
    pub fn from_command_response(option: &str, response: CommandResponse) -> Option<Self> {
        match option {
            "table" => {
                let mut rdr = csv::Reader::from_reader(response.output.as_bytes());
                let headers = rdr
                    .headers()
                    .unwrap()
                    .iter()
                    .map(|s| s.to_string())
                    .collect();
                let mut rows = Vec::new();
                for result in rdr.records() {
                    let record = result.unwrap();
                    let row = record.iter().map(|s| s.to_string()).collect();
                    rows.push(row);
                }
                Some(Outputs::Table(OutputCsv {
                    headers,
                    data: rows,
                }))
            }
            "json" => {
                // use serde to serialize the response object to json
                let json_data = serde_json::to_string(&response).ok()?;
                let json_data: serde_json::Value = serde_json::from_str(&json_data).ok()?;
                Some(Outputs::Json(OutputJson { data: json_data }))
            }
            "yaml" => {
                let yaml_data = serde_yaml::to_string(&response).ok()?;
                let yaml_data: serde_yaml::Value = serde_yaml::from_str(&yaml_data).ok()?;
                Some(Outputs::Yaml(OutputYaml { data: yaml_data }))
            }
            "text" => Some(Outputs::Text(OutputText {
                data: response.output,
            })),
            "ast" => Some(Outputs::Ast(OutAst {
                data: response.output,
            })),
            _ => None,
        }
    }

    pub fn _from_turtle_expression(expression: Expressions) -> Option<Self> {
        match expression {
            Expressions::String(s) => Some(Outputs::Text(OutputText { data: s })),
            Expressions::Number(n) => Some(Outputs::Text(OutputText {
                data: n.to_string(),
            })),
            Expressions::Boolean(b) => Some(Outputs::Text(OutputText {
                data: b.to_string(),
            })),
            _ => None,
        }
    }

    pub fn from_str(option: &str, data: String) -> Option<Self> {
        match option {
            "table" => {
                // parse CSV data
                let mut rdr = csv::Reader::from_reader(data.as_bytes());
                let headers = rdr
                    .headers()
                    .unwrap()
                    .iter()
                    .map(|s| s.to_string())
                    .collect();
                let mut rows = Vec::new();
                for result in rdr.records() {
                    let record = result.unwrap();
                    let row = record.iter().map(|s| s.to_string()).collect();
                    rows.push(row);
                }
                Some(Outputs::Table(OutputCsv {
                    headers,
                    data: rows,
                }))
            }
            "json" => {
                println!("Parsing JSON data...");
                println!("Option: {}", option);
                println!("Data: {}", data);
                let json_data: serde_json::Value = serde_json::from_str(&data).ok()?;
                Some(Outputs::Json(OutputJson { data: json_data }))
            }
            "yaml" => {
                let yaml_data: serde_yaml::Value = serde_yaml::from_str(&data).ok()?;
                Some(Outputs::Yaml(OutputYaml { data: yaml_data }))
            }
            "text" => Some(Outputs::Text(OutputText { data })),
            "ast" => Some(Outputs::Ast(OutAst { data })),
            _ => None,
        }
    }
}

/// CSV compatible output
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct OutputCsv {
    pub headers: Vec<String>,
    pub data: Vec<Vec<String>>,
}

/// YAML compatible output
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct OutputYaml {
    pub data: serde_yaml::Value,
}

/// JSON compatible output
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct OutputJson {
    pub data: serde_json::Value,
}

/// Plain text output
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct OutputText {
    pub data: String,
}

/// AST output
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct OutAst {
    pub data: String,
}

/// outputs for expression results
#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "event")]
pub enum OutputResults {
    #[serde(rename = "command_response")]
    CommandResponse(CommandResponse),
    #[serde(rename = "turtle_expression")]
    TurtleExpression(Expressions),
}

/// a command request to the shell
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct CommandRequest {
    pub id: String,
    pub command: String,
    pub args: Vec<String>,
    pub timestamp: u64,
    // pub event: String,
}

/// a command response from the shell
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct CommandResponse {
    pub id: String,
    pub status: String,
    pub code: i32,
    pub output: String,
    pub errors: String,
    pub timestamp: u64,
    // pub event: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "event")]

/// history event types
pub enum Event {
    // #[serde(rename = "command_request")]
    CommandRequest(CommandRequest),
    // #[serde(rename = "command_response")]
    CommandResponse(CommandResponse),
}

impl fmt::Display for Event {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Event::CommandRequest(req) => write!(
                f,
                "[{}] Command Request: {} {:?}",
                req.timestamp, req.command, req.args
            ),
            Event::CommandResponse(res) => write!(
                f,
                "[{}] Command Response: {} (code: {})",
                res.timestamp, res.output, res.code
            ),
        }
    }
}

/// helper methods for HistoryEvent
impl Event {
    pub fn category(&self) -> &str {
        match self {
            Event::CommandRequest(_) => "CommandRequest",
            Event::CommandResponse(_) => "CommandResponse",
        }
    }

    pub fn as_json(&self) -> serde_json::Value {
        match self {
            Event::CommandRequest(req) => serde_json::to_value(req).unwrap(),
            Event::CommandResponse(res) => serde_json::to_value(res).unwrap(),
        }
    }

    pub fn as_yaml(&self) -> serde_yaml::Value {
        match self {
            Event::CommandRequest(req) => serde_yaml::to_value(req).unwrap(),
            Event::CommandResponse(res) => serde_yaml::to_value(res).unwrap(),
        }
    }

    pub fn as_string(&self) -> String {
        match self {
            Event::CommandRequest(req) => format!("{:?}", req),
            Event::CommandResponse(res) => format!("{:?}", res),
        }
    }

    pub fn as_csv(&self) -> String {
        match self {
            Event::CommandRequest(req) => {
                let mut wtr = csv::Writer::from_writer(vec![]);
                wtr.serialize(req).unwrap();
                let data = String::from_utf8(wtr.into_inner().unwrap()).unwrap();
                data
            }
            Event::CommandResponse(res) => {
                let mut wtr = csv::Writer::from_writer(vec![]);
                wtr.serialize(res).unwrap();
                let data = String::from_utf8(wtr.into_inner().unwrap()).unwrap();
                data
            }
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct History {
    pub debug: bool,
    pub interval: Option<u64>,
    pub path: Option<String>,
    pub events: Option<Vec<Event>>,
}

impl History {
    pub fn new(path: Option<String>, interval: Option<u64>, debug: bool) -> Self {
        if let Some(p) = &path {
            let expanded_path = crate::utils::expand_path(p);
            return History {
                debug,
                path: Some(expanded_path),
                events: Some(Vec::new()),
                interval,
            };
        } else {
            let defaults = crate::types::Defaults::default();
            return History {
                debug,
                path: Some(crate::utils::expand_path(&defaults.history_path)),
                events: Some(Vec::new()),
                interval,
            };
        }
    }

    /// load history from file
    pub fn load(&mut self) -> Option<Vec<crate::types::Event>> {
        if self.path.is_none() {
            println!("❌ History path is not set.");
            return None;
        }

        if let Some(path) = &self.path {
            let content = std::fs::read_to_string(path).ok()?;
            let mut history = Vec::new();
            for line in content.lines() {
                match serde_json::from_str::<crate::types::Event>(line) {
                    Ok(event) => {
                        history.push(event);
                    }
                    Err(_e) => {
                        println!("❌ Failed to parse event from line: {}", line);
                        continue;
                    }
                }
            }

            self.events = Some(history.clone());

            return Some(history.clone());
        }
        None
    }

    /// set up history and load existing events
    pub fn setup(&mut self) {
        if self.events.is_none() {
            self.events = Some(Vec::new());
        }
        // TODO: we should be using the default value here
        self.events = self.load();
    }

    /// add an event to history
    pub fn add(&mut self, event: Event) {
        if let Some(events) = &mut self.events {
            events.push(event);
        }
    }

    /// flush events to file periodically
    pub fn flush(&self) -> std::io::Result<()> {
        use std::io::Write;
        let duration = std::time::Duration::from_secs(self.interval.unwrap_or(60));
        let path = self.path.clone().unwrap();
        let events = self.events.clone().unwrap_or(Vec::new());

        std::thread::spawn(move || {
            loop {
                std::thread::sleep(duration);
                let mut file = std::fs::OpenOptions::new()
                    .create(true)
                    .append(true)
                    .open(&path)
                    .unwrap();
                for event in &events {
                    let json = serde_json::to_string(event).unwrap();

                    writeln!(file, "{}", json).unwrap();
                }
            }
        });
        Ok(())
    }

    /// serialize and save history to file
    pub fn save(&self) -> std::io::Result<()> {
        use std::io::Write;
        let expanded_path = crate::utils::expand_path(self.path.as_ref().unwrap());
        let mut file = std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(expanded_path)?;
        if let Some(events) = &self.events {
            for event in events {
                let json = serde_json::to_string(event).unwrap();
                writeln!(file, "{}", json)?;
            }
            Ok(())
        } else {
            Ok(())
        }
    }

    /// start periodic flushing of history to file
    pub fn start(&mut self) {
        self.setup();
        if let Some(interval) = self.interval {
            self.flush().ok();
            if self.debug {
                println!("✅ History flushing started every {} seconds", interval);
            }
        }
    }
}

/// shell token types
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum Token {
    /// used in function definitions to define their return types, eg: `func foo() -> String { ... }`
    Arrow,

    /// string literals, eg: `"hello"`, `'world'`
    String(String),
    /// numeric literals, eg: `42`, `3.14`
    Number(f64),
    /// a literal `True` or `False`
    Boolean(bool),

    /// a closing brace '}' typically used to complete code blocks or object literals
    BraceClose,
    /// an opening brace '{' typically used to start code blocks or object literals
    BraceOpen,
    /// a closing bracket ']' typically used to complete array literals
    BracketClose,
    /// an opening bracket '[' typically used to start array literals
    BracketOpen,
    /// a closing parenthesis ')' typically used to complete function calls or group expressions
    ParenClose,
    /// an opening parenthesis '(' typically used to start function calls or group expressions
    ParenOpen,
    /// a colon ':' typically used to separate keys and values in objects
    Colon,
    /// a comma ',' typically useseparate items in arrays or parameters in functions
    Comma,

    CodeBlock(Vec<Token>),             // a block of code
    CodeCommentSingleLine(String),     // single line comment
    CodeCommentMultiLineOpen(String),  // multi-line comment
    CodeCommentMultiLineClose(String), // multi-line comment close
    KeywordOpen(String),               // keywords that open blocks: if, else, while, for, func
    KeywordClose(String),              // keywords that close blocks: end, done, return
    Keyword(String),                   // if, else, while, for, func, return, break, continue
    Identifier(String),                // variable names
    Builtin {
        name: String,
        args: Vec<Token>,
    }, // built-in function names
    // Keyword(String),                   // if, else, while, for, func, return, break, continue

    // Shell command and arguments
    ShellArg {
        name: String,
    },
    ShellShortArg {
        name: String,
        values: Vec<Token>,
    },
    ShellLongArg {
        name: String,
        values: Vec<Token>,
    },
    ShellCommand {
        name: String,
        args: String,
    },
    ShellComment(String),
    ShellDot,       // represents the current directory '.'
    ShellDoubleDot, // represents the parent directory '..'
    ShellDirectory {
        segments: Vec<String>,
    },
    ShellFile {
        name: String,
        path: String,
        extension: Option<String>,
    },
    Space,   // single space
    Tab,     // tab character
    Newline, // newline character
    // Whitespace, // spaces, tabs, newlines
    Operator(String),           // +, -, *, /, %, ==, !=, <, >, <=, >=, &&, ||, !
    AdditionOperator,           // +
    SubtractionOperator,        // -
    MultiplicationOperator,     // *
    DivisionOperator,           // /
    ModulusOperator,            // %
    EqualOperator,              // ==
    NotEqualOperator,           // !=
    LessThanOperator,           // <
    GreaterThanOperator,        // >
    LessThanOrEqualOperator,    // <=
    GreaterThanOrEqualOperator, // >=
    AndOperator,                // &&
    OrOperator,                 // ||
    NotOperator,                // !
    Semicolon,                  // ;
    Eof,                        // end of file/input
}

/// shell expression
#[derive(Debug, Clone, Deserialize, Serialize, PartialEq)]
pub enum Expressions {
    /// A number. ex: `1`, `2`, `3`, ...
    Number(f64),

    /// A string. eg: `"hello"`, `'world'`, ...
    String(String),

    /// A boolean. eg: `True`, `False`
    Boolean(bool),

    /// A list of expressions. eg: `[1, 2, 3]`
    Array(Vec<Expressions>),

    /// An object/map/dictionary. eg: `{ "key": value, ... }`
    Object(Vec<(String, Expressions)>),

    /// An object access expression. eg: `obj.property, obj["key"]`
    ///
    /// supports chainable property access: `obj.prop1.prop2["key"]`
    MemberAccess {
        object: Box<Expressions>,
        property: String,
    },
    /// An assignment expression. eg: `let var = value`
    Assignment {
        name: String,
        value: Box<Expressions>,
    },

    /// An identifier. eg: `some_var`
    Identifier(String),
    /// Unary Operation. eg: `-5`, `!true`
    UnaryOperation { op: String, expr: Box<Expressions> },
    /// Binary Operation. eg: `1 + 2`, `x - 3`
    BinaryOperation {
        left: Box<Expressions>,
        op: String,
        right: Box<Expressions>,
    },
    /// If Control Flow - eg: `if cond { ... } else { ... } or if cond { ... }`
    If {
        condition: Box<Expressions>,
        then_branch: Box<Expressions>,
        else_branch: Option<Box<Expressions>>,
    },
    /// While Loop Control Flow - eg: `while cond { ... }`
    While {
        condition: Box<Expressions>,
        body: Box<Expressions>,
    },
    /// For Loop Control Flow - eg: `for i in iterable { ... }`
    For {
        iterator: String,
        iterable: Box<Expressions>,
        body: Box<Expressions>,
    },
    /// Regular Expression - eg: `/pattern/`
    RegularExpression {
        pattern: String,
        flags: Option<String>,
    },
    /// A loop expression. eg: `loop { ... }`
    Loop { body: Box<Expressions> },
    /// fn <name>(<params>) { ... }
    FunctionDefinition {
        name: String,
        params: Vec<String>,
        body: Box<Vec<Expressions>>,
    },
    /// A call to a user defined function. eg: `func(args, ...)`
    FunctionCall {
        func: String,
        args: Vec<Expressions>,
    },

    /// An expression grouping
    /// eg: `(expr)`
    Grouping { expr: Box<Expressions> },
    /// A block of expressions. eg: `{ expr1; expr2; ... }`
    CodeBlock { expressions: Vec<Expressions> },
    /// A built-in function call. eg: print("hello"), alias, exit, ...
    Builtin { name: String, args: String },
    /// An environment variable access. eg: $HOME, $PATH
    EnvironmentVariable { name: String },
    /// A turtle variable access. eg: @turtle_var
    TurtleVariable {
        name: String,
        value: Box<Expressions>,
    },
    /// A shell command execution. eg: ls -la, echo "hello", ...
    ShellCommand { name: String, args: String },
    /// A shell directory path. eg: ./path/to/dir, ../parent/dir, /absolute/path
    Path { segments: Vec<String> },
}

/// Result of evaluating a shell command
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct CommandEvalResult {
    pub stdout: String,
    pub stderr: String,
    pub code: i32,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct BuiltinEvalResult {
    pub output: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct NumberEvalResult {
    pub value: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct StringEvalResult {
    pub value: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct BooleanEvalResult {
    pub value: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ObjectEvalResult {
    pub value: std::collections::HashMap<String, Expressions>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ArrayEvalResult {
    pub value: Vec<Expressions>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct AssignmentEvalResult {
    pub name: String,
    pub value: Expressions,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct EnvironmentVariableEvalResult {
    pub name: String,
    pub value: Option<String>, // value can be None if the variable is not set
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TurtleVariableEvalResult {
    pub name: String,
    pub value: Expressions,
}

/// Expression result enum
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum EvalResults {
    CommandExpressionResult(CommandEvalResult),
    BuiltinExpressionResult(BuiltinEvalResult),
    NumberExpressionResult(NumberEvalResult),
    StringExpressionResult(StringEvalResult),
    BooleanExpressionResult(BooleanEvalResult),
    ObjectExpressionResult(ObjectEvalResult),
    ArrayExpressionResult(ArrayEvalResult),
    AssignmentExpressionResult(AssignmentEvalResult),
    EnvironmentVariableExpressionResult(EnvironmentVariableEvalResult),
    TurtleVariableExpressionResult(TurtleVariableEvalResult),
}

impl fmt::Display for EvalResults {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            EvalResults::CommandExpressionResult(cmd) => write!(
                f,
                "Exit code: {}\nStdout:\n{}\nStderr:\n{}",
                cmd.code, cmd.stdout, cmd.stderr
            ),
            EvalResults::NumberExpressionResult(num) => write!(f, "{}", num.value),
            EvalResults::StringExpressionResult(string) => {
                write!(f, "{}", string.value)
            }
            EvalResults::BooleanExpressionResult(boolean) => {
                write!(f, "{}", boolean.value)
            }
            EvalResults::AssignmentExpressionResult(assign) => {
                write!(f, "Assigned {} to {:?}", assign.name, assign.value)
            }
            EvalResults::ObjectExpressionResult(obj) => {
                let mut output = String::from("{\n");
                for (key, value) in &obj.value {
                    output.push_str(&format!("  {}: {:?}\n", key, value));
                }
                output.push('}');
                write!(f, "{}", output)
            }
            EvalResults::ArrayExpressionResult(arr) => {
                let mut output = String::from("[\n");
                for value in &arr.value {
                    output.push_str(&format!("  {:?}\n", value));
                }
                output.push(']');
                write!(f, "{}", output)
            }
            EvalResults::EnvironmentVariableExpressionResult(env) => match &env.value {
                Some(val) => write!(f, "{}", val),
                None => write!(f, "{} is not set", env.name),
            },
            EvalResults::BuiltinExpressionResult(builtin) => match &builtin.output {
                Some(val) => write!(f, "{}", val),
                None => write!(f, "No output"),
            },
            EvalResults::TurtleVariableExpressionResult(var) => {
                write!(f, "{:?}", var.value)
            }
        }
    }
}

impl EvalResults {
    pub fn from_shell_command_result(stdout: String, stderr: String, code: i32) -> Self {
        EvalResults::CommandExpressionResult(CommandEvalResult {
            stdout,
            stderr,
            code,
        })
    }
}

/// shell builtin command
pub struct Builtin {
    pub name: String,
    pub description: String,
    pub help: String,
    pub execute: Box<
        dyn Fn(
                std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>, // env
                std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>, // aliases
                std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, Expressions>>>, // vars
                std::sync::Arc<std::sync::Mutex<Vec<Event>>>, // history TODO: replace this with history manager (Just pass History  reference)
                Vec<String>,                                  // available builtin names
                Vec<String>,                                  // args
                bool,                                         // debug
                                                              // TODO: consider adding history and the implications of that...
            ) + Send
            + Sync
            + 'static,
    >,
}

impl Builtin {
    pub fn get<'a>(name: &str, builtins: &'a [Builtin]) -> Option<&'a Builtin> {
        builtins.iter().find(|builtin| builtin.name == name)
    }

    pub fn get_builtin(name: &str, builtins: Vec<Builtin>) -> Option<Builtin> {
        for builtin in builtins {
            if builtin.name == name {
                return Some(builtin);
            }
        }
        None
    }
}

impl std::fmt::Debug for Builtin {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("TurtleBuiltin")
            .field("name", &self.name)
            .field("description", &self.description)
            .field("help", &self.help)
            .finish()
    }
}

// #[derive(Debug, Clone)]
pub struct Builtins {
    pub builtins: Vec<Builtin>,
    pub env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    pub aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    pub vars: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, Expressions>>>,
    pub debug: bool,
}

impl std::fmt::Debug for Builtins {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("TurtleBuiltins")
            .field("builtins", &self.builtins)
            .finish()
    }
}

impl Builtins {
    pub fn new(
        builtins: Vec<Builtin>,
        env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        vars: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, Expressions>>>,
        debug: bool,
    ) -> Self {
        Builtins {
            builtins,
            env,
            aliases,
            vars,
            debug,
        }
    }

    pub fn get(&self, name: &str) -> Option<&Builtin> {
        self.builtins.iter().find(|b| b.name == name)
    }

    pub fn list(&self) -> Vec<String> {
        self.builtins.iter().map(|b| b.name.clone()).collect()
    }

    pub fn exec(
        &self,
        name: &str,
        vars: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, Expressions>>>,
        env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        history: std::sync::Arc<std::sync::Mutex<Vec<Event>>>,
        builtin_names: Vec<String>,
        args: Vec<String>,
    ) {
        let debug = self.debug;
        if let Some(builtin) = self.get(name) {
            (builtin.execute)(env, aliases, vars, history, builtin_names, args, debug);
        } else {
            println!("Builtin command '{}' not found", name);
        }
    }
}

/// execution context for Turtle shell
pub struct Context {
    pub debug: bool,
    pub builtins: Option<crate::types::Builtins>,
    pub env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    pub vars: std::sync::Arc<
        std::sync::Mutex<std::collections::HashMap<String, crate::types::Expressions>>,
    >,
    pub aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    pub history: std::sync::Arc<std::sync::Mutex<Vec<crate::types::Event>>>,
    pub functions: std::collections::HashMap<String, crate::types::Expressions>,
    pub code: Vec<crate::types::Expressions>,
}

impl Context {
    /// return available builtins
    fn get_builtins(&self) -> Vec<crate::types::Builtin> {
        vec![
            crate::types::Builtin {
                name: "ast".to_string(),
                description: "Translate a string to Turtle AST".to_string(),
                help: "Usage: ast <code>".to_string(),
                execute: Box::new(|env, aliases, vars, _, builtin_names, args, debug| {
                    let code = args.join(" ");
                    // Evaluate the code
                    let mut interpreter = crate::types::Interpreter::new(
                        env.clone(),
                        aliases.clone(),
                        vars.clone(),
                        builtin_names,
                        debug,
                    );

                    let _tokens = interpreter.tokenize(&code.as_str());
                    let expr = interpreter.interpret();
                    println!("turtle ast: {:?}", expr);
                }),
            },
            crate::types::Builtin {
                name: "tokenize".to_string(),
                description: "Tokenize a string as Turtle code".to_string(),
                help: "Usage: tokenize <code>".to_string(),
                execute: Box::new(|env, aliases, vars, _, builtin_names, args, debug| {
                    let code = args.join(" ");

                    // Evaluate the code
                    let mut interpreter = crate::types::Interpreter::new(
                        env.clone(),
                        aliases.clone(),
                        vars.clone(),
                        builtin_names,
                        debug,
                    );

                    let tokens = interpreter.tokenize(&code.as_str());
                    println!("turtle tokens: {:?}", tokens);
                }),
            },
            crate::types::Builtin {
                name: "eval".to_string(),
                description: "Evaluate a string as Turtle code".to_string(),
                help: "Usage: eval <code>".to_string(),
                execute: Box::new(|env, aliases, vars, history, builtin_names, args, debug| {
                    if args.is_empty() {
                        eprintln!("eval <code>");
                        return;
                    }
                    let code = args.join(" ");
                    let mut interpreter = crate::types::Interpreter::new(
                        env.clone(),
                        aliases.clone(),
                        vars.clone(),
                        builtin_names,
                        debug,
                    );
                    let mut context = crate::types::Context::new(
                        env.clone(),
                        aliases.clone(),
                        vars.clone(),
                        history.clone(),
                        debug,
                    );
                    context.setup();
                    let _tokens = interpreter.tokenize(&code.as_str());
                    let expr = interpreter.interpret();
                    context.eval(expr);
                }),
            },
            crate::types::Builtin {
                name: "history".to_string(),
                description: "Get and Manage command history".to_string(),
                help: "Usage: history".to_string(),
                execute: Box::new(|_, _, _, history, _, args, _| {
                    if args.is_empty() {
                        let history_lock = history.lock().unwrap();

                        if history_lock.is_empty() {
                            println!("No history available.");
                            return;
                        }
                        for (i, event) in history_lock.iter().enumerate() {
                            println!("{}: {:?}", i + 1, event);
                        }
                        return;
                    }
                }),
            },
            crate::types::Builtin {
                name: "noop".to_string(),
                description: "No operation builtin".to_string(),
                help: "Usage: noop".to_string(),
                execute: Box::new(|_, _, _, _, _, _, _| ()),
            },
            crate::types::Builtin {
                name: "exit".to_string(),
                description: "Exit the turtle shell".to_string(),
                help: "Usage: exit".to_string(),
                execute: Box::new(|_, _, _, _, _, _, _| {
                    let _farewell_messages = vec![
                        "Goodbye!",
                        "See you later!",
                        "Exiting Turtle shell. Bye!",
                        "Farewell, adventurer!",
                        "Adios from Turtle shell!",
                    ];

                    std::process::exit(0);
                }),
            },
            // TODO: handle builtins masked by commands that exist
            crate::types::Builtin {
                name: "cd".to_string(),
                description: "Change the current directory".to_string(),
                help: "Usage: cd [directory]".to_string(),
                execute: Box::new(|_, _, _, _, _, args, _| {
                    let home = std::env::var("HOME").unwrap();
                    let dest = args.get(0).map(|s| s.as_str()).unwrap_or(home.as_str());

                    // does the destination exist?
                    if !std::path::Path::new(dest).exists() {
                        eprintln!("cd: no such file or directory: {}", dest);
                        return;
                    }

                    if let Err(e) = std::env::set_current_dir(dest) {
                        eprintln!("cd: {}: {}", dest, e);
                    }
                }),
            },
            crate::types::Builtin {
                name: "alias".to_string(),
                description: "Manage command aliases".to_string(),
                help: "Usage: alias [name='command']".to_string(),
                execute: Box::new(|_, aliases, _, _, _, args, _| {
                    let arg_refs: Vec<&str> = args.iter().map(|s| s.as_str()).collect();

                    // if no args are provided, list all aliases
                    if args.is_empty() {
                        let aliases_lock = aliases.lock().unwrap();
                        for (name, command) in aliases_lock.iter() {
                            println!("alias {}='{}'", name, command);
                        }
                        return;
                    }

                    // user requested args contains '-h' or '--help'
                    if arg_refs.contains(&"-h") || arg_refs.contains(&"--help") {
                        println!("alias [name='command']");
                        println!("Create or display command aliases.");
                        println!("If no arguments are provided, lists all aliases.");
                        return;
                    }

                    // backwards compatibility: support single assignment only
                    if arg_refs.len() == 1 {
                        let assignment = arg_refs[0];
                        if let Some(eq_pos) = assignment.find('=') {
                            let name = &assignment[..eq_pos];
                            let command = &assignment[eq_pos + 1..].trim_matches('\'');
                            let mut aliases_lock = aliases.lock().unwrap();
                            aliases_lock.insert(name.to_string(), command.to_string());
                            println!("Alias set: {}='{}'", name, command);
                        } else {
                            eprintln!("Invalid alias format. Use name='command'");
                        }
                        return;
                    }
                }),
            },
        ]
    }

    /// Initializeexecution context
    pub fn setup(&mut self) {
        let builtins = self.get_builtins();
        self.builtins = Some(crate::types::Builtins {
            env: self.env.clone(),
            aliases: self.aliases.clone(),
            vars: self.vars.clone(),
            builtins,
            debug: self.debug,
        });
    }

    pub fn get_var(&self, name: &str) -> Option<crate::types::Expressions> {
        self.vars.lock().unwrap().get(name).cloned()
    }

    pub fn set_var(&mut self, name: String, value: crate::types::Expressions) {
        self.vars.lock().unwrap().insert(name, value);
    }

    pub fn get_env(&self, name: &str) -> Option<String> {
        self.env.lock().unwrap().get(name).cloned()
    }

    pub fn set_env(&mut self, name: String, value: String) {
        self.env.lock().unwrap().insert(name, value);
    }

    /// Evaluate environment variables: $```<Identifier>```
    fn eval_environment_variable(&mut self, name: &str) -> Option<crate::types::EvalResults> {
        let value = self.get_env(name);
        Some(
            crate::types::EvalResults::EnvironmentVariableExpressionResult(
                crate::types::EnvironmentVariableEvalResult {
                    name: name.to_string(),
                    value,
                },
            ),
        )
    }

    /// Evaluate binary operations: `left (<operator>) right`
    fn eval_binary_operation(
        &mut self,
        left: crate::types::Expressions,
        op: String,
        right: crate::types::Expressions,
    ) -> Option<crate::types::EvalResults> {
        // Recursively evaluate left and right, handling nested BinaryOperation
        let left_result = match left {
            crate::types::Expressions::BinaryOperation { left, op, right } => {
                self.eval_binary_operation(*left, op, *right)?
            }
            _ => self.eval(Some(left))?,
        };

        let right_result = match right {
            crate::types::Expressions::BinaryOperation { left, op, right } => {
                self.eval_binary_operation(*left, op, *right)?
            }
            _ => self.eval(Some(right))?,
        };

        match (left_result, right_result) {
            (
                crate::types::EvalResults::NumberExpressionResult(left_num),
                crate::types::EvalResults::NumberExpressionResult(right_num),
            ) => {
                let result = match op.as_str() {
                    "+" => left_num.value + right_num.value,
                    "-" => left_num.value - right_num.value,
                    "*" => left_num.value * right_num.value,
                    "/" => left_num.value / right_num.value,
                    "%" => left_num.value % right_num.value,
                    _ => {
                        eprintln!("Unsupported operation: {}", op);
                        return None;
                    }
                };
                Some(crate::types::EvalResults::NumberExpressionResult(
                    crate::types::NumberEvalResult { value: result },
                ))
            }
            (
                crate::types::EvalResults::StringExpressionResult(left_str),
                crate::types::EvalResults::StringExpressionResult(right_str),
            ) => {
                if op == "+" {
                    let result = format!("{}{}", left_str.value, right_str.value);
                    Some(crate::types::EvalResults::StringExpressionResult(
                        crate::types::StringEvalResult { value: result },
                    ))
                } else {
                    eprintln!("Unsupported operation for strings: {}", op);
                    None
                }
            }
            _ => {
                eprintln!(
                    "Binary operations are only supported for numbers and string concatenation."
                );
                None
            }
        }
    }

    /// Evaluate assignment expressions: `<Identifier> = <Expression>`
    fn eval_assignment(
        &mut self,
        name: String,
        value: crate::types::Expressions,
    ) -> Option<crate::types::EvalResults> {
        let _evaluated_value = self.eval(Some(value.clone()))?;

        // Store the variable in the context
        println!("Assigning variable: {} = {:?}", name, value);
        self.vars
            .lock()
            .unwrap()
            .insert(name.clone(), value.clone());

        // Return an AssignmentResult
        Some(crate::types::EvalResults::AssignmentExpressionResult(
            crate::types::AssignmentEvalResult { name, value },
        ))
    }

    /// Evaluate variable access: ```<Identifier>```
    fn eval_variable_access(
        &mut self,
        name: &str,
        value: Box<crate::types::Expressions>,
    ) -> Option<crate::types::EvalResults> {
        // get the variables values - this is an expression
        let var = {
            let vars = self.vars.lock().unwrap();
            vars.get(name)?.clone()
        };

        let results = self.eval(Some(var.clone()))?;

        println!(
            "Variable access: {} = {:?}, evaluated to {:?}",
            name, var, results
        );
        return Some(results);
    }

    fn _eval_binary_operation_deprecated(
        &mut self,
        left: crate::types::Expressions,
        op: String,
        right: crate::types::Expressions,
    ) -> Option<crate::types::EvalResults> {
        // we need to handle chained operations

        let left = self.eval(Some(left))?;
        let operation = op;
        let right = self.eval(Some(right))?;

        match (left, right) {
            (
                crate::types::EvalResults::NumberExpressionResult(left_num),
                crate::types::EvalResults::NumberExpressionResult(right_num),
            ) => {
                let result = match operation.as_str() {
                    "+" => left_num.value + right_num.value,
                    "-" => left_num.value - right_num.value,
                    "*" => left_num.value * right_num.value,
                    "/" => left_num.value / right_num.value,
                    "%" => left_num.value % right_num.value,
                    _ => {
                        return None;
                    }
                };
                return Some(crate::types::EvalResults::NumberExpressionResult(
                    crate::types::NumberEvalResult { value: result },
                ));
            }

            // support adding strings for concatenation
            (
                crate::types::EvalResults::StringExpressionResult(left_str),
                crate::types::EvalResults::StringExpressionResult(right_str),
            ) => {
                if operation == "+" {
                    let result = format!("{}{}", left_str.value, right_str.value);
                    return Some(crate::types::EvalResults::StringExpressionResult(
                        crate::types::StringEvalResult { value: result },
                    ));
                } else {
                    return None;
                }
            }
            _ => {
                return None;
            }
        }
    }

    fn eval_builtin(&mut self, name: &str, args: &str) -> Option<crate::types::EvalResults> {
        let env = self.env.clone();
        let aliases = self.aliases.clone();
        let vars = self.vars.clone();
        let history = self.history.clone();

        if let Some(ref builtins) = self.builtins {
            let builtin_names = builtins.list();
            let builtin = builtins.get(name)?;
            let arg_vec: Vec<String> = args.split_whitespace().map(|s| s.to_string()).collect();
            let debug = self.debug;
            let result =
                (builtin.execute)(env, aliases, vars, history, builtin_names, arg_vec, debug);
            return Some(crate::types::EvalResults::BuiltinExpressionResult(
                crate::types::BuiltinEvalResult {
                    output: Some(format!("{:?}", result)),
                },
            ));
        }
        None
    }

    fn eval_command(&mut self, command: &str, args: &str) -> Option<crate::types::EvalResults> {
        use std::process::Command;
        let args_vec: Vec<&str> = args.split_whitespace().collect();

        // construct a command request
        let id = uuid::Uuid::new_v4().to_string();
        let command_request = crate::types::CommandRequest {
            id: id.clone(),
            command: command.to_string(),
            args: args_vec.iter().map(|s| s.to_string()).collect(),
            timestamp: crate::utils::now_unix(),
            // event: "command_request".to_string(),
        };

        self.history
            .lock()
            .unwrap()
            .push(crate::types::Event::CommandRequest(command_request));

        let exec_result = Command::new(command)
            .args(&args_vec)
            .stdin(std::process::Stdio::inherit())
            .output();

        match exec_result {
            Ok(output) => {
                let stdout = String::from_utf8_lossy(&output.stdout);
                let stderr = String::from_utf8_lossy(&output.stderr);
                let code = output.status.code().unwrap_or(-1);
                let result = crate::types::CommandEvalResult {
                    stdout: stdout.to_string(),
                    stderr: stderr.to_string(),
                    code,
                };
                let command_response = crate::types::CommandResponse {
                    id: id.clone(),
                    status: "completed".to_string(),
                    code,
                    output: stdout.to_string(),
                    errors: stderr.to_string(),
                    timestamp: crate::utils::now_unix(),
                };
                self.history
                    .lock()
                    .unwrap()
                    .push(crate::types::Event::CommandResponse(command_response));
                Some(crate::types::EvalResults::CommandExpressionResult(result))
            }
            Err(e) => {
                eprintln!("Failed to execute command: {}", e);
                None
            }
        }
    }

    pub fn new(
        env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        vars: std::sync::Arc<
            std::sync::Mutex<std::collections::HashMap<String, crate::types::Expressions>>,
        >,
        history: std::sync::Arc<std::sync::Mutex<Vec<crate::types::Event>>>,
        debug: bool,
    ) -> Self {
        Context {
            builtins: None,
            env,
            vars,
            aliases,
            history,
            functions: std::collections::HashMap::new(),
            code: Vec::new(),
            debug,
        }
    }

    pub fn eval(
        &mut self,
        expr: Option<crate::types::Expressions>,
    ) -> Option<crate::types::EvalResults> {
        if let Some(ref e) = expr {
            self.code.push(e.clone());
        }
        match expr {
            // handle literal values
            Some(crate::types::Expressions::Assignment { name, value }) => {
                self.eval_assignment(name, value.as_ref().clone())
            }

            // experimental variable access
            Some(crate::types::Expressions::TurtleVariable { name, value }) => {
                self.eval_variable_access(&name, value)
            }

            Some(crate::types::Expressions::BinaryOperation { left, op, right }) => {
                let result = self.eval_binary_operation(*left, op, *right);

                if let Some(crate::types::EvalResults::NumberExpressionResult(n)) = &result {
                    println!("{}", n.value);
                }
                result
            }
            Some(crate::types::Expressions::Number(value)) => {
                Some(crate::types::EvalResults::NumberExpressionResult(
                    crate::types::NumberEvalResult { value },
                ))
            }
            Some(crate::types::Expressions::String(value)) => {
                Some(crate::types::EvalResults::StringExpressionResult(
                    crate::types::StringEvalResult { value },
                ))
            }
            Some(crate::types::Expressions::Boolean(value)) => {
                Some(crate::types::EvalResults::BooleanExpressionResult(
                    crate::types::BooleanEvalResult { value },
                ))
            }
            Some(crate::types::Expressions::Array(values)) => {
                let evaluated_values: Vec<crate::types::Expressions> = values
                    .into_iter()
                    .filter_map(|v| {
                        self.eval(Some(v.clone())).and_then(|res| match res {
                            crate::types::EvalResults::NumberExpressionResult(n) => {
                                Some(crate::types::Expressions::Number(n.value))
                            }
                            crate::types::EvalResults::StringExpressionResult(s) => {
                                Some(crate::types::Expressions::String(s.value))
                            }
                            crate::types::EvalResults::BooleanExpressionResult(b) => {
                                Some(crate::types::Expressions::Boolean(b.value))
                            }
                            _ => None,
                        })
                    })
                    .collect();

                Some(crate::types::EvalResults::ArrayExpressionResult(
                    crate::types::ArrayEvalResult {
                        value: evaluated_values,
                    },
                ))
            }

            Some(crate::types::Expressions::EnvironmentVariable { name }) => {
                self.eval_environment_variable(&name)
            }

            Some(crate::types::Expressions::Builtin { name, args }) => {
                let result = self.eval_builtin(&name, &args);
                result
            }

            Some(crate::types::Expressions::ShellCommand { name, args }) => {
                let result = self.eval_command(&name, &args);
                // result is an option, we need to unwrap it to access the code
                // the result is in the CommandResult variant of ShellResults
                if let Some(crate::types::EvalResults::CommandExpressionResult(cmd)) = &result {
                    if cmd.code != 0 {
                        eprintln!("{}", cmd.stderr);
                    } else {
                        print!("{}", cmd.stdout);
                    }
                }
                result
            }
            _ => {
                println!("Evaluating expression: {:?}", expr);
                None
            }
        }
    }
}

impl std::fmt::Debug for Context {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("TurtleExecutionContext")
            .field("env", &self.env)
            .field("vars", &self.vars)
            .field("aliases", &self.aliases)
            .field("history", &self.history)
            .field("functions", &self.functions)
            .field("code", &self.code)
            .finish()
    }
}
