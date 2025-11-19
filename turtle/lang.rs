/// Turtle language model interactions
///
/// Copyright (c) 2025 Aaron P. Samuel
///
/// Licensed under the MIT License <LICENSE-MIT or http://opensource.org/licenses/MIT>
///
/// **SPDX-License-Identifier**: MIT
///
/// See LICENSE for details.
///

/// Turtle language keywords
pub static KEYWORDS: &[&str] = &[
    "New", "If", "Elseif", "Else", "While", "For", "Break", "Fn", "Return", "Let", "True", "False",
    "Null",
];

/// Abstract Syntax Tree
#[derive(Debug, Clone)]
struct AbstractSyntaxTree {
    /// args
    args: Option<std::sync::Arc<std::sync::Mutex<crate::config::Arguments>>>,
    /// Debugging information
    // debug: bool,
    /// environment variables
    env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    /// command aliases
    aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    /// turtle variables
    vars: std::sync::Arc<
        std::sync::Mutex<std::collections::HashMap<String, crate::expressions::Expressions>>,
    >,
    /// built-in function names
    builtins: Vec<String>,
    /// parsed tokens
    parsed: Vec<crate::tokens::Token>,
    /// current position in tokens
    pos: usize,
}

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
        tokens: Vec<crate::tokens::Token>,
        builtins: Vec<String>,
        env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        vars: std::sync::Arc<
            std::sync::Mutex<std::collections::HashMap<String, crate::expressions::Expressions>>,
        >,
        args: Option<std::sync::Arc<std::sync::Mutex<crate::config::Arguments>>>,
    ) -> Self {
        AbstractSyntaxTree {
            parsed: tokens,
            pos: 0,
            builtins,
            env,
            aliases,
            vars,
            args,
            // debug,
        }
    }

    /// peek at the current token
    pub fn peek(&self) -> &crate::tokens::Token {
        // if
        if self.args.is_some() {
            let args = self.args.as_ref().unwrap().lock().unwrap();

            if args.debug {
                println!(
                    "peeking at token position {}: {:?}",
                    self.pos,
                    self.parsed.get(self.pos)
                );
            }
        }

        self.parsed
            .get(self.pos)
            .unwrap_or(&crate::tokens::Token::Eof)
    }

    /// get the next token
    pub fn next(&mut self) -> &crate::tokens::Token {
        if self.args.is_some() {
            let args = self.args.as_ref().unwrap().lock().unwrap();

            if args.debug {
                println!(
                    "Getting next token at position {}: {:?}",
                    self.pos,
                    self.parsed.get(self.pos)
                );
            }
        }

        let tok = self
            .parsed
            .get(self.pos)
            .unwrap_or(&crate::tokens::Token::Eof);
        self.pos += 1;
        tok
    }

    /// skip whitespace tokens (space, tab, newline)
    fn skip_whitespace(&mut self) {
        while matches!(
            self.peek(),
            crate::tokens::Token::Space | crate::tokens::Token::Tab | crate::tokens::Token::Newline
        ) {
            self.next();
        }
    }

    /// parse literal values (Numbers, Strings, Booleans)
    fn parse_literal(&mut self) -> Option<crate::expressions::Expressions> {
        match self.next() {
            crate::tokens::Token::Number(n) => Some(crate::expressions::Expressions::Number(*n)),
            crate::tokens::Token::String(s) => {
                Some(crate::expressions::Expressions::String(s.clone()))
            }
            crate::tokens::Token::Boolean(b) => Some(crate::expressions::Expressions::Boolean(*b)),
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
    fn parse_unary(&mut self) -> Option<crate::expressions::Expressions> {
        self.skip_whitespace();
        if let crate::tokens::Token::Operator(op) = self.peek() {
            if op == "-" || op == "!" || op == "~" {
                let op = op.clone();
                if self.args.is_some() {
                    let args = self.args.as_ref().unwrap().lock().unwrap();

                    if args.debug {
                        println!(
                            "🔧 parse_unary: found unary operator '{}', pos={}, token={:?}",
                            op,
                            self.pos,
                            self.peek()
                        );
                    }
                }

                self.next(); // consume operator
                self.skip_whitespace();
                if self.args.is_some() {
                    let args = self.args.as_ref().unwrap().lock().unwrap();

                    if args.debug {
                        println!(
                            "🔧 parse_unary: after consuming operator, pos={}, token={:?}",
                            self.pos,
                            self.peek()
                        );
                    }
                }

                if let Some(expr) = self.parse_expr() {
                    return Some(crate::expressions::Expressions::UnaryOperation {
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
        left: crate::expressions::Expressions,
    ) -> Option<crate::expressions::Expressions> {
        if let crate::tokens::Token::Operator(op) = self.peek() {
            let op = op.clone();
            self.next(); // consume operator

            if let Some(right) = self.parse_expr() {
                return Some(crate::expressions::Expressions::BinaryOperation {
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
        mut left: crate::expressions::Expressions,
    ) -> crate::expressions::Expressions {
        loop {
            self.skip_whitespace(); // skip spaces before operator
            let op = match self.peek() {
                crate::tokens::Token::Operator(op) => op.clone(),
                _ => break,
            };
            let prec = self.get_operator_precedence(&op);
            if prec < min_prec {
                break;
            }
            self.next(); // consume operator
            self.skip_whitespace(); // skip any spaces after the operator

            // Parse the right-hand side with higher precedence
            let mut right = self
                .parse_primary()
                .unwrap_or(crate::expressions::Expressions::Number(0.0));
            self.skip_whitespace(); // skip spaces before checking for next operator
            while let crate::tokens::Token::Operator(next_op) = self.peek() {
                let next_prec = self.get_operator_precedence(next_op);
                if next_prec > prec {
                    right = self.parse_binary_with_precedence(next_prec, right);
                } else {
                    break;
                }
            }

            left = crate::expressions::Expressions::BinaryOperation {
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
    fn parse_function_def(&mut self) -> Option<crate::expressions::Expressions> {
        self.skip_whitespace();
        if let crate::tokens::Token::Keyword(k) = self.peek() {
            if k == "fn" {
                self.next(); // consume 'fn'
                self.skip_whitespace();
                let func_name = if let crate::tokens::Token::Identifier(name) = self.peek() {
                    let name = name.clone();
                    self.next(); // consume function name
                    self.skip_whitespace();
                    name
                } else {
                    return None; // expected function name
                };

                // parse parameters
                if let crate::tokens::Token::ParenOpen = self.peek() {
                    self.next(); // consume '('
                    self.skip_whitespace();
                    let mut params = Vec::new();
                    while !matches!(
                        self.peek(),
                        crate::tokens::Token::ParenClose | crate::tokens::Token::Eof
                    ) {
                        if let crate::tokens::Token::Identifier(param) = self.peek() {
                            params.push(param.clone());
                            self.next(); // consume parameter
                            self.skip_whitespace();
                        }
                        if let crate::tokens::Token::Comma = self.peek() {
                            self.next(); // consume ','
                            self.skip_whitespace();
                        } else {
                            break;
                        }
                    }
                    if let crate::tokens::Token::ParenClose = self.peek() {
                        self.next(); // consume ')'
                        self.skip_whitespace();
                    } else {
                        return None; // expected ')'
                    }

                    // parse function body
                    if let crate::tokens::Token::BraceOpen = self.peek() {
                        self.next(); // consume '{'
                        let mut body = Vec::new();
                        while !matches!(
                            self.peek(),
                            crate::tokens::Token::BraceClose | crate::tokens::Token::Eof
                        ) {
                            if let Some(expr) = self.parse_expr() {
                                body.push(expr);
                            } else {
                                // skip unknown tokens (?)
                                self.next(); // skip unknown tokens
                                self.skip_whitespace();
                            }
                        }
                        if let crate::tokens::Token::BraceClose = self.peek() {
                            self.next(); // consume '}'
                            self.skip_whitespace();
                            return Some(crate::expressions::Expressions::FunctionDefinition {
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
        expr: crate::expressions::Expressions,
    ) -> Option<crate::expressions::Expressions> {
        if let crate::tokens::Token::ParenOpen = self.peek() {
            self.next(); // consume '('
            let mut args = Vec::new();
            while !matches!(
                self.peek(),
                crate::tokens::Token::ParenClose | crate::tokens::Token::Eof
            ) {
                if let Some(arg) = self.parse_expr() {
                    args.push(arg);
                }
                if let crate::tokens::Token::Comma = self.peek() {
                    self.next(); // consume ','
                } else {
                    break;
                }
            }
            if let crate::tokens::Token::ParenClose = self.peek() {
                self.next(); // consume ')'
                // Use expr as the function (can be Identifier or MemberAccess)
                return Some(crate::expressions::Expressions::FunctionCall {
                    func: match expr {
                        crate::expressions::Expressions::Identifier(ref name) => name.clone(),
                        crate::expressions::Expressions::MemberAccess { .. } => {
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
        expr: crate::expressions::Expressions,
    ) -> Option<crate::expressions::Expressions> {
        if let crate::tokens::Token::ShellDot = self.peek() {
            self.next(); // consume '.'
            if let crate::tokens::Token::Identifier(property) = self.peek() {
                let property = property.clone();
                self.next(); // consume property identifier
                return Some(crate::expressions::Expressions::MemberAccess {
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
    fn parse_literal_array(&mut self) -> Option<crate::expressions::Expressions> {
        if let crate::tokens::Token::BracketOpen = self.peek() {
            self.next(); // consume '['
            self.skip_whitespace(); // skip whitespace after opening bracket
            let mut elements = Vec::new();
            while !matches!(
                self.peek(),
                crate::tokens::Token::BracketClose | crate::tokens::Token::Eof
            ) {
                if let Some(expr) = self.parse_expr() {
                    elements.push(expr);
                }

                self.skip_whitespace(); // skip whitespace before comma or closing bracket
                if let crate::tokens::Token::Comma = self.peek() {
                    self.next(); // consume ','
                    self.skip_whitespace(); // skip whitespace after comma
                } else {
                    break;
                }
            }

            if let crate::tokens::Token::BracketClose = self.peek() {
                self.next(); // consume ']'
                return Some(crate::expressions::Expressions::Array(elements));
            } else {
                return None; // expected ']'
            }
        }
        None
    }

    /// parse new array constructor
    /// ```
    /// new Array()
    /// new Array([1, 2, 3])
    /// ```
    fn parse_new_array(&mut self) -> Option<crate::expressions::Expressions> {
        // Save position for backtracking
        let start_pos = self.pos;

        // Check for 'New' keyword
        if let crate::tokens::Token::Keyword(k) = self.peek() {
            if k != "New" {
                return None;
            }
            self.next(); // consume 'New'
            self.skip_whitespace();

            // Check for 'Array' identifier
            if let crate::tokens::Token::Identifier(name) = self.peek() {
                if name != "Array" {
                    self.pos = start_pos; // restore position
                    return None;
                }
                self.next(); // consume 'Array'
                self.skip_whitespace();

                // Check for '('
                if let crate::tokens::Token::ParenOpen = self.peek() {
                    self.next(); // consume '('
                    self.skip_whitespace();

                    // Check for optional array literal argument
                    if let crate::tokens::Token::BracketOpen = self.peek() {
                        // Parse the array literal
                        let array_expr = self.parse_literal_array()?;
                        self.skip_whitespace();

                        // Check for ')'
                        if let crate::tokens::Token::ParenClose = self.peek() {
                            self.next(); // consume ')'
                            return Some(array_expr);
                        } else {
                            self.pos = start_pos; // restore position
                            return None;
                        }
                    } else if let crate::tokens::Token::ParenClose = self.peek() {
                        // Empty constructor: new Array()
                        self.next(); // consume ')'
                        return Some(crate::expressions::Expressions::Array(Vec::new()));
                    } else {
                        self.pos = start_pos; // restore position
                        return None;
                    }
                } else {
                    self.pos = start_pos; // restore position
                    return None;
                }
            } else {
                self.pos = start_pos; // restore position
                return None;
            }
        }
        None
    }

    /// parse new object constructor
    /// ```
    /// new Object()
    /// new Object({foo: 1, bar: 2})
    /// ```
    fn parse_new_object(&mut self) -> Option<crate::expressions::Expressions> {
        // Save position for backtracking
        let start_pos = self.pos;

        // Check for 'New' keyword
        if let crate::tokens::Token::Keyword(k) = self.peek() {
            if k != "New" {
                return None;
            }
            self.next(); // consume 'New'
            self.skip_whitespace();

            // Check for 'Object' identifier
            if let crate::tokens::Token::Identifier(name) = self.peek() {
                if name != "Object" {
                    self.pos = start_pos; // restore position
                    return None;
                }
                self.next(); // consume 'Object'
                self.skip_whitespace();

                // Check for '('
                if let crate::tokens::Token::ParenOpen = self.peek() {
                    self.next(); // consume '('
                    self.skip_whitespace();

                    // Check for optional object literal argument
                    if let crate::tokens::Token::BraceOpen = self.peek() {
                        // Parse the object literal
                        let object_expr = self.parse_object()?;
                        self.skip_whitespace();

                        // Check for ')'
                        if let crate::tokens::Token::ParenClose = self.peek() {
                            self.next(); // consume ')'
                            return Some(object_expr);
                        } else {
                            self.pos = start_pos; // restore position
                            return None;
                        }
                    } else if let crate::tokens::Token::ParenClose = self.peek() {
                        // Empty constructor: new Object()
                        self.next(); // consume ')'
                        return Some(crate::expressions::Expressions::Object(Vec::new()));
                    } else {
                        self.pos = start_pos; // restore position
                        return None;
                    }
                } else {
                    self.pos = start_pos; // restore position
                    return None;
                }
            } else {
                self.pos = start_pos; // restore position
                return None;
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
    fn parse_object(&mut self) -> Option<crate::expressions::Expressions> {
        if let crate::tokens::Token::BraceOpen = self.peek() {
            self.next(); // consume '{'
            self.skip_whitespace(); // skip whitespace after opening brace
            let mut properties = Vec::new();
            while !matches!(
                self.peek(),
                crate::tokens::Token::BraceClose | crate::tokens::Token::Eof
            ) {
                // Get the key as a cloned value
                let key_token = self.next().clone();
                let key = if let crate::tokens::Token::Identifier(ref k) = key_token {
                    k.clone()
                } else {
                    return None; // expected identifier key
                };

                self.skip_whitespace(); // skip whitespace before colon
                if let crate::tokens::Token::Colon = self.peek() {
                    self.next(); // consume ':'
                    self.skip_whitespace(); // skip whitespace after colon
                    if let Some(value) = self.parse_expr() {
                        properties.push((key, value));
                    } else {
                        return None; // expected value expression
                    }
                } else {
                    return None; // expected ':'
                }

                self.skip_whitespace(); // skip whitespace before comma or closing brace
                if let crate::tokens::Token::Comma = self.peek() {
                    self.next(); // consume ','
                    self.skip_whitespace(); // skip whitespace after comma
                } else {
                    break;
                }
            }
            if let crate::tokens::Token::BraceClose = self.peek() {
                self.next(); // consume '}'
                return Some(crate::expressions::Expressions::Object(properties));
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
    fn parse_assignment(&mut self) -> Option<crate::expressions::Expressions> {
        self.skip_whitespace();
        // handle assignments prefixed with the let keyword
        if let crate::tokens::Token::Keyword(k) = self.peek() {
            if k == "Let" {
                self.next(); // consume 'let'
                self.skip_whitespace();
                if let crate::tokens::Token::Identifier(name) = self.peek() {
                    let name = name.clone();
                    self.next(); // consume identifier
                    self.skip_whitespace();

                    if let crate::tokens::Token::Operator(op) = self.peek() {
                        if op == "=" {
                            self.next(); // consume '='
                            self.skip_whitespace();
                            if let Some(value) = self.parse_expr() {
                                return Some(crate::expressions::Expressions::Assignment {
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
        if let crate::tokens::Token::Identifier(name) = self.peek() {
            let start_pos = self.pos; // Save position for backtracking
            let name = name.clone();
            self.next(); // consume identifier
            self.skip_whitespace();

            if let crate::tokens::Token::Operator(op) = self.peek() {
                if op == "=" {
                    self.next(); // consume '='
                    self.skip_whitespace();
                    if let Some(value) = self.parse_expr() {
                        return Some(crate::expressions::Expressions::Assignment {
                            name,
                            value: Box::new(value),
                        });
                    } else {
                        return None; // expected value expression
                    }
                } else {
                    // Not an assignment operator, restore position
                    self.pos = start_pos;
                    return None;
                }
            } else {
                // No operator after identifier, restore position
                self.pos = start_pos;
            }
        }

        // parse reassignments without the let keyword
        // if let crate::tokens::Token::Identifier(name) = self.peek() {
        // }

        None
    }

    /// parse primitive expressions
    ///
    /// 1
    /// "hello"
    /// [1, 2, 3]
    fn parse_primary(&mut self) -> Option<crate::expressions::Expressions> {
        // Check for Array.new() constructor syntax first
        if let Some(array_expr) = self.parse_new_array() {
            return Some(array_expr);
        }

        // Check for Object.new() constructor syntax
        if let Some(object_expr) = self.parse_new_object() {
            return Some(object_expr);
        }

        // Parse the initial literal, identifier, array, or object
        let mut expr = match self.peek() {
            // literals
            crate::tokens::Token::Number(_)
            | crate::tokens::Token::String(_)
            | crate::tokens::Token::Boolean(_) => self.parse_literal(),
            // arrays & objects
            // crate::tokens::Token::ShellDot => self.parse_new_array(),
            crate::tokens::Token::BracketOpen => self.parse_literal_array(),
            // adds parsing
            crate::tokens::Token::BraceOpen => self.parse_object(),
            // identifiers
            crate::tokens::Token::Identifier(name) => {
                let ident = name.clone();
                self.next(); // consume identifier
                Some(crate::expressions::Expressions::Identifier(ident))
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

    fn parse_environment_variable(&mut self) -> Option<crate::expressions::Expressions> {
        if let crate::tokens::Token::Operator(op) = self.peek() {
            if op == "$" {
                self.next(); // consume '$'
                if let crate::tokens::Token::Identifier(name) = self.peek() {
                    let name = name.clone();
                    self.next(); // consume identifier
                    return Some(crate::expressions::Expressions::EnvironmentVariable { name });
                }
            }
        }
        None
    }

    // TODO: the
    fn parse_builtin(&mut self) -> Option<crate::expressions::Expressions> {
        if let crate::tokens::Token::Identifier(cmd) = self.peek() {
            let cmd = cmd.clone();

            if !self.builtins.contains(&cmd) {
                return None;
            }
            self.next(); // consume builtin identifier

            let mut input_args = String::new();
            if let Some(args) = &self.args {
                let args = args.lock().unwrap();
                if args.debug {
                    println!("parse_builtin: found builtin '{}'", cmd);
                }
            }
            if let Some(args) = &self.args {
                let args = args.lock().unwrap();
                if args.debug {
                    println!("parse_builtin: collecting args for builtin '{}'", cmd);
                }
            }
            while !matches!(
                self.peek(),
                crate::tokens::Token::Eof | crate::tokens::Token::Semicolon
            ) {
                if let Some(args) = &self.args {
                    let args = args.lock().unwrap();
                    if args.debug {
                        println!("parse_builtin: current token: {:?}", self.peek());
                    }
                }
                match self.peek() {
                    crate::tokens::Token::Space
                    | crate::tokens::Token::Tab
                    | crate::tokens::Token::Newline => {
                        input_args.push(' ');
                        self.next(); // consume whitespace
                    }
                    crate::tokens::Token::String(s) => {
                        input_args.push_str(&format!("\"{}\"", s));
                        self.next(); // consume string
                    }
                    crate::tokens::Token::Number(n) => {
                        input_args.push_str(&n.to_string());
                        self.next(); // consume number
                    }
                    crate::tokens::Token::Identifier(id) => {
                        input_args.push_str(id);
                        self.next(); // consume identifier
                    }
                    crate::tokens::Token::Operator(op) => {
                        input_args.push_str(op);
                        self.next(); // consume operator
                    }
                    crate::tokens::Token::BracketOpen => {
                        input_args.push('[');
                        self.next(); // consume bracket
                    }
                    crate::tokens::Token::BracketClose => {
                        input_args.push(']');
                        self.next(); // consume bracket
                    }
                    crate::tokens::Token::BraceOpen => {
                        input_args.push('{');
                        self.next(); // consume brace
                    }
                    crate::tokens::Token::BraceClose => {
                        input_args.push('}');
                        self.next(); // consume brace
                    }
                    crate::tokens::Token::Comma => {
                        input_args.push(',');
                        self.next(); // consume comma
                    }
                    crate::tokens::Token::Colon => {
                        input_args.push(':');
                        self.next(); // consume colon
                    }
                    _ => {
                        self.next(); // consume unknown token
                    }
                }
            }

            if let crate::tokens::Token::Semicolon = self.peek() {
                self.next(); // consume ';'
            }
            if let Some(args) = &self.args {
                let args = args.lock().unwrap();
                if args.debug {
                    println!("parse_builtin: final args string: '{}'", input_args);
                }
            }
            return Some(crate::expressions::Expressions::Builtin {
                name: cmd,
                args: input_args.trim().to_string(),
            });
        }
        None
    }

    // fn parse_variable
    fn parse_command(&mut self) -> Option<crate::expressions::Expressions> {
        if let crate::tokens::Token::Identifier(cmd) = self.peek() {
            let cmd = cmd.clone();
            if !crate::utils::is_command(&cmd) {
                return None;
            }
            self.next(); // consume command identifier

            let mut args = String::new();
            while !matches!(
                self.peek(),
                crate::tokens::Token::Eof | crate::tokens::Token::Semicolon
            ) {
                match self.peek() {
                    crate::tokens::Token::Space
                    | crate::tokens::Token::Tab
                    | crate::tokens::Token::Newline => {
                        args.push(' ');
                        self.next(); // consume whitespace
                    }
                    crate::tokens::Token::String(s) => {
                        args.push_str(&format!("\"{}\"", s));
                        self.next(); // consume string
                    }
                    crate::tokens::Token::Number(n) => {
                        args.push_str(&n.to_string());
                        self.next(); // consume number
                    }
                    crate::tokens::Token::Identifier(id) => {
                        args.push_str(id);
                        self.next(); // consume identifier
                    }
                    crate::tokens::Token::Operator(op) => {
                        args.push_str(op);
                        self.next(); // consume operator
                    }
                    &crate::tokens::Token::ShellDot => {
                        args.push('.');
                        self.next(); // consume dot
                    }
                    &crate::tokens::Token::ShellDoubleDot => {
                        args.push_str("..");
                        self.next(); // consume double dot
                    }
                    &crate::tokens::Token::BracketOpen => {
                        args.push('[');
                        self.next(); // consume '['
                    }
                    &crate::tokens::Token::BracketClose => {
                        args.push(']');
                        self.next(); // consume ']'
                    }
                    &crate::tokens::Token::ParenOpen => {
                        args.push('(');
                        self.next(); // consume '('
                    }
                    &crate::tokens::Token::ParenClose => {
                        args.push(')');
                        self.next(); // consume ')'
                    }
                    &crate::tokens::Token::BraceOpen => {
                        args.push('{');
                        self.next(); // consume '{'
                    }
                    &crate::tokens::Token::BraceClose => {
                        args.push('}');
                        self.next(); // consume '}'
                    }
                    &crate::tokens::Token::Comma => {
                        args.push(',');
                        self.next(); // consume ','
                    }
                    _ => {
                        self.next(); // consume unknown token
                    }
                }
            }

            if let crate::tokens::Token::Semicolon = self.peek() {
                self.next(); // consume ';'
            }
            return Some(crate::expressions::Expressions::ShellCommand {
                name: cmd,
                args: args.trim().to_string(),
            });
        }
        None
    }

    /// implements parsing rules to build TurtleExpression AST
    pub fn parse_expr(&mut self) -> Option<crate::expressions::Expressions> {
        if let Some(args) = &self.args {
            let args = args.lock().unwrap();
            if args.debug {
                println!(
                    "Parsing expression at token position {}: {:?}",
                    self.pos,
                    self.peek()
                );
            }
        }

        // parse  built-in functions
        if let Some(builtin) = self.parse_builtin() {
            return Some(builtin);
        }
        // parse shell commands
        if let Some(command) = self.parse_command() {
            return Some(command);
        }

        // parse assignments
        if let Some(assignment) = self.parse_assignment() {
            return Some(assignment);
        }

        // // parse variable access - experimental
        // if let Some(var_expr) = self.parse_variable() {
        //     return Some(var_expr);
        // }

        // parse environment variables
        // if let Some(env_var) = self.parse_environment_variable() {
        //     return Some(env_var);
        // }

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

        if let Some(args) = &self.args {
            let args = args.lock().unwrap();
            if args.debug {
                println!(
                    "🔍 After primary parse - expr: {:?}, current token: {:?}",
                    expr,
                    self.peek()
                );
            }
        }

        // parse unary operations
        if expr.is_none() {
            if let Some(args) = &self.args {
                let args = args.lock().unwrap();
                if args.debug {
                    println!("🔍 Expr is None, attempting to parse unary operation");
                }
            }
        } else {
            if let Some(args) = &self.args {
                let args = args.lock().unwrap();
                if args.debug {
                    println!(
                        "🔍 Expr is Some({:?}), skipping unary operation parsing",
                        expr
                    );
                }
            }
        }
        if let Some(unary) = self.parse_unary() {
            println!("🔍 Parsed unary operation: {:?}", unary);
            return Some(unary);
        }
        // if expr.is_none() {}

        // skip whitespace before checking for binary operations
        self.skip_whitespace();

        // parse binary operations (chained)
        while let Some(crate::tokens::Token::Operator(_)) = self.peek().clone().into() {
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

/// Tokenization & Interpretation
#[derive(Debug, Clone)]
pub struct Interpreter {
    // debug: bool,
    args: Option<std::sync::Arc<std::sync::Mutex<crate::config::Arguments>>>,
    env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    vars: std::sync::Arc<
        std::sync::Mutex<std::collections::HashMap<String, crate::expressions::Expressions>>,
    >,
    builtins: Vec<String>,
    counter: usize,
    tokens: Vec<crate::tokens::Token>, // parser: Option<TurtleParser>,
}

impl Interpreter {
    /// initialize the interpreter
    pub fn new(
        args: Option<std::sync::Arc<std::sync::Mutex<crate::config::Arguments>>>,
        env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        vars: std::sync::Arc<
            std::sync::Mutex<std::collections::HashMap<String, crate::expressions::Expressions>>,
        >,
        builtins: Vec<String>,
        debug: bool,
    ) -> Self {
        if debug {
            println!("🚛 initializing Interpreter");
        }
        Interpreter {
            args,
            env,
            aliases,
            vars,
            builtins,
            counter: 0,
            tokens: Vec::new(),
            // debug,
        }
    }

    /// tokenize primitive tokens from input string, e.g., identifiers, numbers, strings, operators
    pub fn tokenize_primitives(&mut self, input: &str) -> Vec<crate::tokens::Token> {
        if let Some(args) = &self.args {
            let args = args.lock().unwrap();
            if args.debug {
                println!("tokenize_primitives input: {:?}", input);
            }
        }

        let mut tokens = Vec::new();
        let mut chars = input.chars().peekable();
        while let Some(&c) = chars.peek() {
            match c {
                // parentheses for grouping expressions and function calls
                '(' => {
                    tokens.push(crate::tokens::Token::ParenOpen);
                    chars.next();
                }
                ')' => {
                    tokens.push(crate::tokens::Token::ParenClose);
                    chars.next();
                }
                // braces for objects, blocks and scopes
                '{' => {
                    tokens.push(crate::tokens::Token::BraceOpen);
                    chars.next();
                }
                '}' => {
                    tokens.push(crate::tokens::Token::BraceClose);
                    chars.next();
                }
                // brackets for arrays
                '[' => {
                    tokens.push(crate::tokens::Token::BracketOpen);
                    chars.next();
                }
                ']' => {
                    tokens.push(crate::tokens::Token::BracketClose);
                    chars.next();
                }
                // colon for key-value pairs and type annotations
                ':' => {
                    tokens.push(crate::tokens::Token::Colon);
                    chars.next();
                }
                // semicolon for statement termination
                ';' => {
                    tokens.push(crate::tokens::Token::Semicolon);
                    chars.next();
                }
                // arrow operator for function return types and lambdas
                '-' => {
                    chars.next();
                    if let Some(&'>') = chars.peek() {
                        tokens.push(crate::tokens::Token::Arrow);
                        chars.next();
                    } else {
                        tokens.push(crate::tokens::Token::Operator("-".to_string()));
                    }
                }
                // comma for separating items in lists and function arguments
                ',' => {
                    tokens.push(crate::tokens::Token::Comma);
                    chars.next();
                }
                // dots for relative paths and identifiers
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
                            tokens.push(crate::tokens::Token::Identifier(identifier));
                        } else {
                            // old pattern
                            if let Some('.') = chars.clone().nth(1) {
                                tokens.push(crate::tokens::Token::ShellDoubleDot);
                                chars.next(); // consume first '.'
                                chars.next(); // consume second '.'/
                            } else {
                                tokens.push(crate::tokens::Token::ShellDot);
                                chars.next(); // consume first '.'
                            }
                        }
                    } else {
                        tokens.push(crate::tokens::Token::ShellDot);
                        chars.next(); // <-- Always consume first '.'
                    }
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
                        tokens.push(crate::tokens::Token::Newline);
                    } else if ws.contains('\t') {
                        tokens.push(crate::tokens::Token::Tab);
                    } else {
                        tokens.push(crate::tokens::Token::Space);
                    }
                    // chars.next();
                }
                // string literals
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
                    tokens.push(crate::tokens::Token::String(s));
                }
                // number literals
                '0'..='9' => {
                    let mut num = String::new();
                    while let Some(&d) = chars.peek() {
                        if d.is_ascii_digit() || d == '.' {
                            num.push(d);
                            chars.next();
                        } else {
                            break; // stop parsing number at any non-digit/dot character
                        }
                    }
                    tokens.push(crate::tokens::Token::Number(num.parse().unwrap()))
                }
                // global env var indicator
                '$' => {
                    tokens.push(crate::tokens::Token::Operator("$".to_string()));
                    chars.next();
                }
                // identifiers and keywords
                _ if c.is_alphanumeric() || c == '_' || c == '.' => {
                    let mut identifier = String::new();
                    while let Some(&d) = chars.peek() {
                        if d.is_alphanumeric() || d == '_' || d == '.' {
                            identifier.push(d);
                            chars.next();
                        } else {
                            break;
                        }
                    }

                    // check for boolean literals
                    let canonical = identifier[..1].to_ascii_uppercase() + &identifier[1..];
                    if KEYWORDS.contains(&canonical.as_str()) {
                        tokens.push(crate::tokens::Token::Keyword(canonical));
                        continue;
                    } else if identifier == "True" {
                        tokens.push(crate::tokens::Token::Boolean(true));
                    } else if identifier == "False" {
                        tokens.push(crate::tokens::Token::Boolean(false));
                    } else {
                        tokens.push(crate::tokens::Token::Identifier(identifier));
                    }
                }
                // operators
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
                    tokens.push(crate::tokens::Token::Operator(op));
                }
                // unrecognized characters
                _ => {
                    chars.next();
                }
            }
        }

        tokens.push(crate::tokens::Token::Eof);
        if let Some(args) = &self.args {
            let args = args.lock().unwrap();
            if args.debug {
                println!("tokenize_primitives output: {:?}", tokens);
            }
        }

        tokens
    }

    /// Tokenize shell commands and args
    #[deprecated]
    pub fn tokenize_shell_commands(
        &mut self,
        tokens: Vec<crate::tokens::Token>,
    ) -> Vec<crate::tokens::Token> {
        let mut result: Vec<crate::tokens::Token> = Vec::new();
        let mut iter = tokens.into_iter().peekable();

        while let Some(token) = iter.next() {
            match &token {
                crate::tokens::Token::ShellCommand { name, .. } => {
                    let mut args = String::new();
                    while let Some(next_token) = iter.peek() {
                        match next_token {
                            crate::tokens::Token::Eof | crate::tokens::Token::Semicolon => break,

                            // BUG: handle ShellCommands embedded in other shell commands
                            // the name and args need to be extracted properly
                            // and joined
                            // Handle dash-arguments: -ah, -l, etc.
                            crate::tokens::Token::Operator(op) if op == "-" => {
                                let mut arg = String::from("-");
                                iter.next(); // consume '-'
                                // Concatenate following identifiers (e.g., "ah" in "-ah")
                                while let Some(crate::tokens::Token::Identifier(s)) = iter.peek() {
                                    arg.push_str(s);
                                    iter.next();
                                }
                                if !args.is_empty() {
                                    args.push(' ');
                                }
                                args.push_str(&arg);
                            }

                            // Handle paths: /Users, ./foo, ../bar
                            crate::tokens::Token::Operator(op) if op == "/" || op == "." => {
                                let mut path = String::new();
                                // Collect all consecutive Operator/Identifier tokens
                                while let Some(tok) = iter.peek() {
                                    match tok {
                                        crate::tokens::Token::Operator(op)
                                            if op == "/" || op == "." =>
                                        {
                                            path.push_str(op);
                                            iter.next();
                                        }
                                        crate::tokens::Token::Identifier(seg) => {
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
                            crate::tokens::Token::String(s) => {
                                if !args.is_empty() {
                                    args.push(' ');
                                }
                                args.push('"');
                                args.push_str(s);
                                args.push('"');
                                iter.next();
                            }

                            // Handle numbers
                            crate::tokens::Token::Number(n) => {
                                if !args.is_empty() {
                                    args.push(' ');
                                }
                                args.push_str(&n.to_string());
                                iter.next();
                            }

                            // Handle identifiers (not part of dash-args or paths)
                            crate::tokens::Token::Identifier(s) => {
                                if !args.is_empty() {
                                    args.push(' ');
                                }
                                args.push_str(s);
                                iter.next();
                            }

                            // Handle other operators (e.g., dots)
                            crate::tokens::Token::Operator(op) => {
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
                    result.push(crate::tokens::Token::ShellCommand {
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
        tokens: Vec<crate::tokens::Token>,
    ) -> Vec<crate::tokens::Token> {
        let mut result: Vec<crate::tokens::Token> = Vec::new();
        let mut iter = tokens.into_iter().peekable();

        while let Some(token) = iter.next() {
            match &token {
                crate::tokens::Token::Builtin { name, args } => {
                    let mut args = Vec::new();
                    while let Some(next_token) = iter.peek() {
                        match next_token {
                            crate::tokens::Token::Eof | crate::tokens::Token::Semicolon => break,

                            crate::tokens::Token::Operator(op) if op == "-" => {
                                iter.next(); // consume first '-'
                                // Handles long arg and their values
                                if let Some(crate::tokens::Token::Operator(op2)) = iter.peek() {
                                    if op2 == "-" {
                                        iter.next(); // consume second '-'
                                        if let Some(crate::tokens::Token::Identifier(name)) =
                                            iter.peek()
                                        {
                                            let name = name.clone();
                                            iter.next(); // consume builtin name
                                            let mut values = Vec::new();
                                            // Optionally, collect values after long arg
                                            while let Some(val_token) = iter.peek() {
                                                match val_token {
                                                    crate::tokens::Token::String(_)
                                                    | crate::tokens::Token::Identifier(_) => {
                                                        values.push(iter.next().unwrap());
                                                    }
                                                    _ => break,
                                                }
                                            }
                                            args.push(crate::tokens::Token::ShellLongArg {
                                                name,
                                                values,
                                            });
                                            continue;
                                        }
                                    }
                                }
                                // Handles short arg and their values
                                if let Some(crate::tokens::Token::Identifier(name)) = iter.peek() {
                                    let name = name.clone();
                                    iter.next(); // consume builtin name
                                    let mut values = Vec::new();
                                    // Optionally, collect values after short arg
                                    while let Some(val_token) = iter.peek() {
                                        match val_token {
                                            crate::tokens::Token::String(_)
                                            | crate::tokens::Token::Identifier(_) => {
                                                if let crate::tokens::Token::Operator(op) =
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
                                    args.push(crate::tokens::Token::ShellShortArg { name, values });
                                    continue;
                                }

                                // If no valid arg name follows '-', treat as normal arg
                                // handle path like identifiers
                                // TODO - handle ../ and ./ path variants
                            }

                            // Handle absolute path args: /foo/bar
                            crate::tokens::Token::Operator(op) if op == "/" => {
                                let mut path = String::from("/");
                                iter.next(); // consume '/'
                                while let Some(next_seg) = iter.peek() {
                                    match next_seg {
                                        crate::tokens::Token::Identifier(seg) => {
                                            if path != "/" {
                                                path.push('/');
                                            }
                                            path.push_str(seg);
                                            iter.next(); // consume segment
                                        }
                                        crate::tokens::Token::Operator(op2) if op2 == "/" => {
                                            path.push('/');
                                            iter.next(); // consume '/'
                                        }
                                        crate::tokens::Token::Number(n) => {
                                            path.push_str(&n.to_string());
                                            iter.next(); // consume segment
                                        }
                                        crate::tokens::Token::String(s) => {
                                            path.push_str(s);
                                            iter.next(); // consume segment
                                        }
                                        crate::tokens::Token::Eof
                                        | crate::tokens::Token::Semicolon => break,
                                        crate::tokens::Token::Operator(op) if op == "-" => {
                                            break;
                                        }
                                        _ => break,
                                    }
                                }
                                args.push(crate::tokens::Token::ShellDirectory {
                                    segments: path.split('/').map(|s| s.to_string()).collect(),
                                });
                                continue;
                            }

                            // Handle relative path args: ./foo/bar
                            crate::tokens::Token::Operator(op) if op == "." => {
                                let mut path = String::from(".");
                                iter.next(); // consume '.'
                                if let Some(crate::tokens::Token::Operator(op2)) = iter.peek() {
                                    if op2 == "/" {
                                        path.push('/');
                                        iter.next(); // consume '/'
                                        while let Some(next_seg) = iter.peek() {
                                            match next_seg {
                                                crate::tokens::Token::Identifier(seg) => {
                                                    if !path.ends_with('/') {
                                                        path.push('/');
                                                    }
                                                    path.push_str(seg);
                                                    iter.next(); // consume segment
                                                }
                                                crate::tokens::Token::Operator(op3)
                                                    if op3 == "/" =>
                                                {
                                                    path.push('/');
                                                    iter.next(); // consume '/'
                                                }
                                                _ => break,
                                            }
                                        }
                                        args.push(crate::tokens::Token::ShellDirectory {
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
                            crate::tokens::Token::Identifier(arg) => {
                                args.push(crate::tokens::Token::ShellArg { name: arg.clone() });
                                iter.next(); // consume arg
                            }

                            _ => {
                                args.push(iter.next().unwrap());
                            }
                        }
                    }
                    result.push(crate::tokens::Token::Builtin {
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
    pub fn tokenize(&mut self, input: &str) -> Vec<crate::tokens::Token> {
        if let Some(args) = &self.args {
            let args = args.lock().unwrap();
            if args.debug {
                println!("=== TOKENIZE PIPELINE START ===");
                println!("Input: {:?}", input);
            }
        }

        let tokens = Self::tokenize_primitives(self, input);
        if let Some(args) = &self.args {
            let args = args.lock().unwrap();
            if args.debug {
                println!("After tokenize_primitives: {:?}", tokens);
            }
        }

        let tokens: Vec<crate::tokens::Token> = Self::tokenize_builtin_functions(self, tokens);
        if let Some(args) = &self.args {
            let args = args.lock().unwrap();
            if args.debug {
                println!("After tokenize_builtin_functions: {:?}", tokens);
                println!("=== TOKENIZE PIPELINE END ===");
            }
        }

        self.tokens = tokens.clone();
        self.counter += 1;
        tokens
    }

    /// Generate AST from tokens
    pub fn interpret(&mut self) -> Option<crate::expressions::Expressions> {
        let tokens = self.tokens.clone();
        let mut parser = AbstractSyntaxTree::new(
            tokens,
            self.builtins.clone(),
            self.env.clone(),
            self.aliases.clone(),
            self.vars.clone(),
            self.args.clone(),
        );
        parser.parse_expr()
    }
}
