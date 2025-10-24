// mod types;

pub static _TURTLE_BUILTIN_FUNCTIONS: &[&str] = &[
    "builtin", "alias", "print", "input", "len", "which", "whereis", "cd", "exit", "help",
];

pub static _TURTLE_KEYWORDS: &[&str] = &[
    // if (condition) { ... } else { ... } || if (condition) { ... }
    "if", "else", "while", "for", "fn", "return", "let", "true", "false",
];

#[derive(Debug, Clone)]
struct TurtleParser {
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


    /// parse function calls
    /// ex: foo(arg1, arg2, ...)
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
                return Some(crate::types::TurtleExpression::FuncCall {
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

    /// parse member access: object.property
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
    /// ex: [expr1, expr2, expr3]
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
    /// ex: { key1: value1, key2: value2 }
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

    fn _parse_primary(&mut self) -> Option<crate::types::TurtleExpression> {
        let mut expr = match self.peek() {
            crate::types::TurtleToken::Number(_)
            | crate::types::TurtleToken::String(_)
            | crate::types::TurtleToken::Boolean(_) => self.parse_literal(),
            crate::types::TurtleToken::Identifier(name) => {
                let ident = name.clone();
                self.next();
                Some(crate::types::TurtleExpression::Identifier(ident))
            }
            crate::types::TurtleToken::BracketOpen => self.parse_array(),
            crate::types::TurtleToken::BraceOpen => self.parse_object(),
            _ => None,
        }?;

        // Chain member access and function calls modularly
        loop {
            if let Some(member_expr) = self.parse_member_access(expr.clone()) {
                expr = member_expr;
                continue;
            }
            if let Some(call_expr) = self.parse_function_call(expr.clone()) {
                expr = call_expr;
                continue;
            }
            break;
        }
        Some(expr)
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



#[derive(Debug, Clone)]
pub struct TurtleInterpreter {
    counter: usize,
    tokens: Vec<crate::types::TurtleToken>
    // parser: Option<TurtleParser>,
}

impl TurtleInterpreter {
    pub fn new() -> Self {
        TurtleInterpreter { counter: 0, tokens: Vec::new() }
    }

    /// basic tokenization of input string
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

                        // check if the is an executable, treat as command, else as a path
                        // /
                        // ../
                        // ./

                        // if ident.starts_with("./") || ident.starts_with("/") || ident.starts_with("../") {
                        //   if crate::utils::_is_command_in_path(&ident) || std::path::Path::new(&ident).is_file() {
                        //       tokens.push(crate::types::TurtleToken::ShellCommand { name: ident, args: Vec::new() });
                        //       continue;
                        //   } else if crate::utils::_is_a_path(&ident) {
                        //       tokens.push(crate::types::TurtleToken::ShellPath { segments: ident.split('/').map(|s| s.to_string()).collect() });
                        //       continue;
                        //   }
                        // }

                        // check if identifier is a keyword
                        if _TURTLE_KEYWORDS.contains(&ident.as_str()) {
                            tokens.push(crate::types::TurtleToken::Keyword(ident));
                            continue;
                        }

                        // check if identifier is a builtinn function
                        if _TURTLE_BUILTIN_FUNCTIONS.contains(&ident.as_str()) {
                            tokens.push(crate::types::TurtleToken::Builtin { name: ident, args: Vec::new() });
                            continue;
                        }

                        // check if the identifier is a command in the PATH

                        if crate::utils::is_command(&ident) {
                            // println!("Identified command: {}", ident);
                            tokens.push(crate::types::TurtleToken::ShellCommand { name: ident, args: Vec::new() });
                            continue;
                        }
                        // NOTE: some identifiers are processed during subsequent passes of lexigraphical analysis
                        // - Path vs Command vs Identifier
                        // - Builtin vs Keyword vs Identifier
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

    /// secondary tokenization pass to identify shell paths
    pub fn tokenize_secondary(&mut self, tokens: Vec<crate::types::TurtleToken>) -> Vec<crate::types::TurtleToken> {
        let mut result = Vec::new();
        let mut i = 0;

        while i < tokens.len() {
            // Handle absolute path: /foo/bar
            if let crate::types::TurtleToken::Operator(ref op) = tokens[i] {
                if op == "/" {
                    let mut path = String::from("/");
                    let mut j = i + 1;
                    while j < tokens.len() {
                        match &tokens[j] {
                            crate::types::TurtleToken::Identifier(seg) => {
                                if path != "/" {
                                    path.push('/');
                                }
                                path.push_str(seg);
                                j += 1;
                            }
                            crate::types::TurtleToken::Operator(op2) if op2 == "/" => {
                                path.push('/');
                                j += 1;
                            }
                            _ => break,
                        }
                    }
                    result.push(crate::types::TurtleToken::ShellDirectory { segments: path.split('/').map(|s| s.to_string()).collect() });
                    i = j;
                    continue;
                }
            }

            // Handle relative path: ./foo/bar
            if i + 1 < tokens.len() {
                if let (crate::types::TurtleToken::Operator(op1), crate::types::TurtleToken::Operator(op2)) = (&tokens[i], &tokens[i + 1]) {
                    if op1 == "." && op2 == "/" {
                        let mut path = String::from("./");
                        let mut j = i + 2;
                        while j < tokens.len() {
                            match &tokens[j] {
                                crate::types::TurtleToken::Identifier(seg) => {
                                    if !path.ends_with('/') {
                                        path.push('/');
                                    }
                                    path.push_str(seg);
                                    j += 1;
                                }
                                crate::types::TurtleToken::Operator(op3) if op3 == "/" => {
                                    path.push('/');
                                    j += 1;
                                }
                                _ => break,
                            }
                        }
                        result.push(crate::types::TurtleToken::ShellDirectory { segments: path.split('/').map(|s| s.to_string()).collect() });
                        i = j;
                        continue;
                    }
                }
            }

            // Handle relative path: ../foo/bar
            if i + 2 < tokens.len() {
                if let (
                    crate::types::TurtleToken::Operator(op1),
                    crate::types::TurtleToken::Operator(op2),
                    crate::types::TurtleToken::Operator(op3),
                ) = (&tokens[i], &tokens[i + 1], &tokens[i + 2])
                {
                    if op1 == "." && op2 == "." && op3 == "/" {
                        let mut path = String::from("../");
                        let mut j = i + 3;
                        while j < tokens.len() {
                            match &tokens[j] {
                                crate::types::TurtleToken::Identifier(seg) => {
                                    if !path.ends_with('/') {
                                        path.push('/');
                                    }
                                    path.push_str(seg);
                                    j += 1;
                                }
                                crate::types::TurtleToken::Operator(op4) if op4 == "/" => {
                                    path.push('/');
                                    j += 1;
                                }
                                _ => break,
                            }
                        }
                        result.push(crate::types::TurtleToken::ShellDirectory { segments: path.split('/').map(|s| s.to_string()).collect() });
                        i = j;
                        continue;
                    }
                }
            }

            // Default: push token as-is
            result.push(tokens[i].clone());
            i += 1;
        }

        result
    }

    /// tokenize shell commands and their arguments
    pub fn tokenize_shell_commands(&mut self, tokens: Vec<crate::types::TurtleToken>) -> Vec<crate::types::TurtleToken> {
        let mut result: Vec<crate::types::TurtleToken> = Vec::new();
        // let mut processed_tokens = Vec::new();
        let mut iter = tokens.into_iter().peekable();

        while let Some(token) = iter.next() {
            match &token {
                crate::types::TurtleToken::ShellCommand { name, args } => {
                    let mut args = Vec::new();
                    while let Some(next_token) = iter.peek() {
                        match next_token {
                            crate::types::TurtleToken::Eof| crate::types::TurtleToken::Semicolon => break,


                            crate::types::TurtleToken::Operator(op) if op == "-" => {
                                iter.next(); // consume first '-'
                                // Handles long arg and their values
                                if let Some(crate::types::TurtleToken::Operator(op2)) = iter.peek() {
                                    if op2 == "-" {
                                        iter.next(); // consume second '-'
                                        if let Some(crate::types::TurtleToken::Identifier(name)) = iter.peek() {
                                            let name = name.clone();
                                            iter.next(); // consume builtin name
                                            let mut values = Vec::new();
                                            // Optionally, collect values after long arg
                                            while let Some(val_token) = iter.peek() {
                                                match val_token {
                                                    crate::types::TurtleToken::String(_) | crate::types::TurtleToken::Identifier(_) => {
                                                        values.push(iter.next().unwrap());
                                                    }
                                                    _ => break,
                                                }
                                            }
                                            args.push(crate::types::TurtleToken::ShellLongArg { name, values });
                                            continue;
                                        }
                                    }
                                }
                                // Handles short arg and their values
                                if let Some(crate::types::TurtleToken::Identifier(name)) = iter.peek() {
                                    let name = name.clone();
                                    iter.next(); // consume builtin name
                                    let mut values = Vec::new();
                                    // Optionally, collect values after short arg
                                    while let Some(val_token) = iter.peek() {
                                        match val_token {
                                            crate::types::TurtleToken::String(_)
                                            | crate::types::TurtleToken::Identifier(_)
                                            => {
                                                if let crate::types::TurtleToken::Operator(op) = val_token {
                                                    if op == "-" {
                                                        break;
                                                    }
                                                }
                                                values.push(iter.next().unwrap());
                                            }
                                            _ => break,
                                        }
                                    }
                                    args.push(crate::types::TurtleToken::ShellShortArg { name, values });
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
                                    println!("Identified path segment token: {:?}", next_seg);
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
                                        crate::types::TurtleToken::Operator(op) if op == "-" => break,
                                        _ => break,
                                    }
                                }
                                args.push(crate::types::TurtleToken::ShellDirectory { segments: path.split('/').map(|s| s.to_string()).collect() });
                                continue;
                            }

                            // Handle relative path args: ./foo/bar
                            crate::types::TurtleToken::Operator(op) if op == "." => {
                              let mut path = String::from(".");
                              iter.next(); // consume '.'
                              if let Some(crate::types::TurtleToken::Operator(op2)) = iter.peek() {
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
                                            crate::types::TurtleToken::Operator(op3) if op3 == "/" => {
                                                path.push('/');
                                                iter.next(); // consume '/'
                                            }
                                            _ => break,
                                        }
                                    }
                                    args.push(crate::types::TurtleToken::ShellDirectory { segments: path.split('/').map(|s| s.to_string()).collect() });
                                    continue;
                                }
                              }
                            }

                            // Handle relative path args: ../foo/bar
                            crate::types::TurtleToken::Identifier(arg) => {
                              args.push(crate::types::TurtleToken::ShellArg { name: arg.clone()});
                              iter.next(); // consume arg
                            }

                            _ => {
                                iter.next().unwrap();
                            }
                        }
                    }
                    result.push(crate::types::TurtleToken::ShellCommand { name: name.clone(), args });
                    // processed_tokens.push(crate::types::TurtleToken::ShellCommand { name: name.clone(), args: args });
                }
                _ => {
                    // processed_tokens.push(token);
                    result.push(token);
                }
            }
        }

        // processed_tokens
        result
    }

    /// tokenize built-in function calls and their arguments, these typically appear as normal args
    // we will reuse ShellArg, ShellShortArg and ShellLongArg token types for built-in args
    // we will use the same flow we use for tokenizing shell commands
    pub fn tokenize_builtin_functions(&mut self, tokens: Vec<crate::types::TurtleToken>) -> Vec<crate::types::TurtleToken> {
        let mut result: Vec<crate::types::TurtleToken> = Vec::new();
        let mut iter = tokens.into_iter().peekable();

        while let Some(token) = iter.next() {
            match &token {
                crate::types::TurtleToken::Builtin { name, args } => {
                    let mut args = Vec::new();
                    while let Some(next_token) = iter.peek() {
                        match next_token {
                            crate::types::TurtleToken::Eof| crate::types::TurtleToken::Semicolon => break,

                            crate::types::TurtleToken::Operator(op) if op == "-" => {
                                iter.next(); // consume first '-'
                                // Handles long arg and their values
                                if let Some(crate::types::TurtleToken::Operator(op2)) = iter.peek() {
                                    if op2 == "-" {
                                        iter.next(); // consume second '-'
                                        if let Some(crate::types::TurtleToken::Identifier(name)) = iter.peek() {
                                            let name = name.clone();
                                            iter.next(); // consume builtin name
                                            let mut values = Vec::new();
                                            // Optionally, collect values after long arg
                                            while let Some(val_token) = iter.peek() {
                                                match val_token {
                                                    crate::types::TurtleToken::String(_) | crate::types::TurtleToken::Identifier(_) => {
                                                        values.push(iter.next().unwrap());
                                                    }
                                                    _ => break,
                                                }
                                            }
                                            args.push(crate::types::TurtleToken::ShellLongArg { name, values });
                                            continue;
                                        }
                                    }
                                }
                                // Handles short arg and their values
                                if let Some(crate::types::TurtleToken::Identifier(name)) = iter.peek() {
                                    let name = name.clone();
                                    iter.next(); // consume builtin name
                                    let mut values = Vec::new();
                                    // Optionally, collect values after short arg
                                    while let Some(val_token) = iter.peek() {
                                        match val_token {
                                            crate::types::TurtleToken::String(_)
                                            | crate::types::TurtleToken::Identifier(_)
                                            => {
                                                if let crate::types::TurtleToken::Operator(op) = val_token {
                                                    if op == "-" {
                                                        break;
                                                    }
                                                }
                                                values.push(iter.next().unwrap());
                                            }
                                            _ => break,
                                        }
                                    }
                                    args.push(crate::types::TurtleToken::ShellShortArg { name, values });
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
                                    println!("Identified path segment token: {:?}", next_seg);
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
                                        crate::types::TurtleToken::Operator(op) if op == "-" => break,
                                        _ => break,
                                    }
                                }
                                println!("Identified absolute path arg: {}", path);
                                args.push(crate::types::TurtleToken::ShellDirectory { segments: path.split('/').map(|s| s.to_string()).collect() });
                                continue;
                            }

                            // Handle relative path args: ./foo/bar
                            crate::types::TurtleToken::Operator(op) if op == "." => {
                              let mut path = String::from(".");
                              iter.next(); // consume '.'
                              if let Some(crate::types::TurtleToken::Operator(op2)) = iter.peek() {
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
                                            crate::types::TurtleToken::Operator(op3) if op3 == "/" => {
                                                path.push('/');
                                                iter.next(); // consume '/'
                                            }
                                            _ => break,
                                        }
                                    }
                                    args.push(crate::types::TurtleToken::ShellDirectory { segments: path.split('/').map(|s| s.to_string()).collect() });
                                    continue;
                                }
                              }
                            }


                            // Handle relative path args: ../foo/bar
                            crate::types::TurtleToken::Identifier(arg) => {
                              args.push(crate::types::TurtleToken::ShellArg { name: arg.clone()});
                              iter.next(); // consume arg
                            }

                            _ => {
                                args.push(iter.next().unwrap());
                            }
                        }
                    }
                  result.push(crate::types::TurtleToken::Builtin { name: name.clone(), args });
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
        let tokens = Self::tokenize_shell_commands(self, tokens);
        // let tokens = Self::tokenize_secondary(self, tokens);

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
