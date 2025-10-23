// mod types;

pub static _TURTLE_BUILTIN_FUNCTIONS: &[&str] = &[
    "builtin", "alias", "print", "input", "len", "which", "whereis", "cd", "exit", "help",
];

pub static _TURTLE_KEYWORDS: &[&str] = &[
    // if (condition) { ... } else { ... } || if (condition) { ... }
    "if", "else", "while", "for", "fn", "return", "let", "true", "false",
];

#[derive(Debug, Clone)]
pub struct TurtleParser {
    tokens: Vec<crate::types::TurtleToken>,
    pos: usize,
}

impl TurtleParser {
    pub fn new(tokens: Vec<crate::types::TurtleToken>) -> Self {
        TurtleParser { tokens, pos: 0 }
    }

    pub fn peek(&self) -> &crate::types::TurtleToken {
        self.tokens
            .get(self.pos)
            .unwrap_or(&crate::types::TurtleToken::Eof)
    }

    pub fn next(&mut self) -> &crate::types::TurtleToken {
        let tok = self
            .tokens
            .get(self.pos)
            .unwrap_or(&crate::types::TurtleToken::Eof);
        self.pos += 1;
        tok
    }

    /// parse literal values: numbers, strings, booleans
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

    /// parse unary expressions: -5, !true, ~false
    fn parse_unary(&mut self) -> Option<crate::types::TurtleExpression> {
        if let crate::types::TurtleToken::Operator(op) = self.peek() {
            if op == "-" || op == "!" || op == "~" {
                let op = op.clone();
                self.next(); // consume operator
                if let Some(expr) = self.parse_expr() {
                    return Some(crate::types::TurtleExpression::UnaryExpression {
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

    /// parse binary expressions: 1 + 2, x - 3, "hello" + " world"
    fn parse_binary(
        &mut self,
        left: crate::types::TurtleExpression,
    ) -> Option<crate::types::TurtleExpression> {
        if let crate::types::TurtleToken::Operator(op) = self.peek() {
            let op = op.clone();
            self.next(); // consume operator

            if let Some(right) = self.parse_expr() {
                return Some(crate::types::TurtleExpression::BinaryExpression {
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

    /// parse member access: object.property
    fn _parse_member_access(
        &mut self,
        ) -> Option<crate::types::TurtleExpression> {
        if let crate::types::TurtleToken::Identifier(object_name) = self.peek() {
            let object_name = object_name.clone();
            self.next(); // consume object identifier

            if let crate::types::TurtleToken::Operator(op) = self.peek() {
                if op == "." {
                    self.next(); // consume '.'
                    if let crate::types::TurtleToken::Identifier(property) = self.peek() {
                        let property = property.clone();
                        self.next(); // consume property identifier
                        return Some(crate::types::TurtleExpression::MemberAccess {
                            object: Box::new(crate::types::TurtleExpression::Identifier(object_name)),
                            property,
                        });
                    }
                }
            }
        }
        None
    }

    /// parse arrays
    /// ex: [expr1, expr2, expr3]
    fn _parse_array(&mut self) -> Option<crate::types::TurtleExpression> {
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
    /// ex: { key1: value1, key2: value2 }
    fn _parse_object(&mut self) -> Option<crate::types::TurtleExpression> {
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

    /// parse function calls
    /// ex: foo(arg1, arg2, ...)
    fn parse_function_call(&mut self) -> Option<crate::types::TurtleExpression> {
        if let crate::types::TurtleToken::Identifier(func_name) = self.peek() {
            let func_name = func_name.clone();
            self.next(); // consume identifier

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
                    return Some(crate::types::TurtleExpression::FuncCall {
                        func: func_name,
                        args,
                    });
                } else {
                    return None; // expected ')'
                }
            } else {
                // Not a function call, rewind position
                self.pos -= 1;
            }
        }
        None
    }

    /// parse primary expressions: literals, identifiers, function calls
    fn __parse_primary(&mut self) -> Option<crate::types::TurtleExpression> {
        match self.peek() {
            crate::types::TurtleToken::Number(_)
            | crate::types::TurtleToken::String(_)
            | crate::types::TurtleToken::Boolean(_) => self.parse_literal(),

            crate::types::TurtleToken::Identifier(name) => {
                let func_name = name.clone();
                self.next(); // consume identifier

                // Only parse function call if next token is ParenOpen
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
                        return Some(crate::types::TurtleExpression::FuncCall {
                            func: func_name,
                            args,
                        });
                    } else {
                        return None; // expected ')'
                    }
                } else {
                    // Just an identifier
                    return Some(crate::types::TurtleExpression::Identifier(func_name));
                }
            }
            _ => None,
        }
    }

    fn parse_primary(&mut self) -> Option<crate::types::TurtleExpression> {
        match self.peek() {
            crate::types::TurtleToken::Number(_)
            | crate::types::TurtleToken::String(_)
            | crate::types::TurtleToken::Boolean(_) => self.parse_literal(),

            crate::types::TurtleToken::Identifier(_) => {
                // Try to parse as a function call first
                if let Some(func_call) = self.parse_function_call() {
                    return Some(func_call);
                }

                // // Try to parse a member access
                // if let Some(member_access) = self._parse_member_access() {
                //     return Some(member_access);
                // }


                // If not a function call, parse as identifier
                if let crate::types::TurtleToken::Identifier(name) = self.peek() {
                    let ident = name.clone();
                    self.next(); // consume identifier
                    return Some(crate::types::TurtleExpression::Identifier(ident));
                }
                None
            }
            _ => None,
        }
    }

    /// implements parsing rules to build TurtleExpression AST
    pub fn parse_expr(&mut self) -> Option<crate::types::TurtleExpression> {
        /*
          - parse unary expressions like: -5, !True, ~False
        */
        if let Some(expr) = self.parse_unary() {
            return Some(expr);
        }

        /*
          - parse primary expressions: literals, identifiers, function calls
        */
        if let Some(expr) = self.parse_primary() {
            return Some(expr);
        }

        /*
          - parse function calls like: print("Hello, World!") or len(my_list)
        */
        // if let Some(expr) = self.parse_function_call() {
        //     return Some(expr);
        // }

        /*
          - parse simple binary expressions like: 1 + 2, x - 3, "hello" + " world"
        */

        // parse the left side
        let left = match self.next() {
            crate::types::TurtleToken::Number(n) => {
                Some(crate::types::TurtleExpression::Number(*n))
            }
            crate::types::TurtleToken::String(s) => {
                Some(crate::types::TurtleExpression::String(s.clone()))
            }
            crate::types::TurtleToken::Identifier(id) => {
                Some(crate::types::TurtleExpression::Identifier(id.clone()))
            }
            _ => None,
        };

        if let Some(ref l) = left.clone() {
            if let Some(expr) = self.parse_binary(l.clone()) {
                return Some(expr);
            }
        }

        left
    }
}

// TODO: move this function definition to TurtleParser implementation
pub fn lex(input: &str) -> Vec<crate::types::TurtleToken> {
    let mut tokens = Vec::new();
    let mut chars = input.chars().peekable();
    while let Some(&c) = chars.peek() {
        match c {
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

            // parens define a function call
            ' ' | '\t' | '\n' => {
                chars.next();
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
            _ if c.is_alphabetic() || c == "_".chars().next().unwrap() => {
                let mut ident = String::new();
                while let Some(&d) = chars.peek() {
                    if d.is_alphanumeric() || d == "_".chars().next().unwrap() {
                        ident.push(d);
                        chars.next();
                    } else {
                        break;
                    }
                }
                if ident == "True" {
                    tokens.push(crate::types::TurtleToken::Boolean(true));
                } else if ident == "False" {
                    tokens.push(crate::types::TurtleToken::Boolean(false));
                } else {
                    // check if ident is a builtin function
                    // if TURTLE_BUILTIN_FUNCTIONS.contains(&ident.as_str()) {
                    //   tokens.push(crate::types::TurtleToken::Builtin(ident));
                    //   continue;
                    // }

                    // if TURTLE_KEYWORDS.contains(&ident.as_str()) {
                    //   tokens.push(crate::types::TurtleToken::Keyword(ident));
                    //   continue;
                    // }

                    // check if the ident is a command in the PATH
                    // we need the first part only (before any spaces)
                    // split ident by whitespace
                    // let parts: Vec<&str> = ident.split_whitespace().collect();
                    // let possible_command = parts[0];
                    // let possible_args = &parts[1..];
                    // println!("Possible command: {}", possible_command);
                    // println!("Possible args: {:?}", possible_args);
                    // if crate::utils::is_command_in_path(possible_command) {
                    //   tokens.push(crate::types::TurtleToken::Command {
                    //     name: possible_command.to_string(),
                    //     args: possible_args.iter().map(|s| crate::types::TurtleToken::String(s.to_string())).collect(),
                    //   });
                    //   continue;
                    // }

                    tokens.push(crate::types::TurtleToken::Identifier(ident));
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

#[derive(Debug, Clone)]
pub struct TurtleInterpreter {
    // input: String,
    parser: Option<TurtleParser>,
}

impl TurtleInterpreter {
    pub fn new(parser: Option<TurtleParser>) -> Self {
        TurtleInterpreter { parser }
    }

    pub fn interpret(&mut self, input: &str) -> Option<crate::types::TurtleExpression> {
        let tokens = lex(input);
        let mut parser = TurtleParser::new(tokens);
        parser.parse_expr()
    }

    pub fn tokenize(&mut self, input: &str) -> Vec<crate::types::TurtleToken> {
        let mut tokens = Vec::new();
        let mut chars = input.chars().peekable();
        while let Some(&c) = chars.peek() {
            match c {
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

                // parens define a function call
                ' ' | '\t' | '\n' => {
                    chars.next();
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
                _ if c.is_alphabetic() || c == "_".chars().next().unwrap() => {
                    let mut ident = String::new();
                    while let Some(&d) = chars.peek() {
                        if d.is_alphanumeric() || d == "_".chars().next().unwrap() {
                            ident.push(d);
                            chars.next();
                        } else {
                            break;
                        }
                    }
                    if ident == "True" {
                        tokens.push(crate::types::TurtleToken::Boolean(true));
                    } else if ident == "False" {
                        tokens.push(crate::types::TurtleToken::Boolean(false));
                    } else {
                        // check if ident is a builtin function
                        // if TURTLE_BUILTIN_FUNCTIONS.contains(&ident.as_str()) {
                        //   tokens.push(crate::types::TurtleToken::Builtin(ident));
                        //   continue;
                        // }

                        // if TURTLE_KEYWORDS.contains(&ident.as_str()) {
                        //   tokens.push(crate::types::TurtleToken::Keyword(ident));
                        //   continue;
                        // }

                        // check if the ident is a command in the PATH
                        // we need the first part only (before any spaces)
                        // split ident by whitespace
                        // let parts: Vec<&str> = ident.split_whitespace().collect();
                        // let possible_command = parts[0];
                        // let possible_args = &parts[1..];
                        // println!("Possible command: {}", possible_command);
                        // println!("Possible args: {:?}", possible_args);
                        // if crate::utils::is_command_in_path(possible_command) {
                        //   tokens.push(crate::types::TurtleToken::Command {
                        //     name: possible_command.to_string(),
                        //     args: possible_args.iter().map(|s| crate::types::TurtleToken::String(s.to_string())).collect(),
                        //   });
                        //   continue;
                        // }

                        tokens.push(crate::types::TurtleToken::Identifier(ident));
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
}
