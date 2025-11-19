use serde::{Deserialize, Serialize};

/// Format a floating-point number according to format specifier
fn format_number(num: f64, spec: &str) -> String {
    if spec.is_empty() {
        return format!("{}", num);
    }

    // Parse format spec
    let spec = spec.trim_start_matches(':');

    // Check for precision (.N)
    if let Some(dot_pos) = spec.find('.') {
        if let Ok(precision) = spec[dot_pos + 1..].parse::<usize>() {
            return format!("{:.prec$}", num, prec = precision);
        }
    }

    // Check for width and alignment
    if let Some(first_char) = spec.chars().next() {
        let (align, rest) = match first_char {
            '<' => ("left", &spec[1..]),
            '^' => ("center", &spec[1..]),
            '0' => {
                // Zero-padded
                if let Ok(width) = spec[1..].parse::<usize>() {
                    return format!("{:0width$}", num, width = width);
                }
                ("right", spec)
            }
            _ => ("right", spec),
        };

        if let Ok(width) = rest.parse::<usize>() {
            let s = format!("{}", num);
            return match align {
                "left" => format!("{:<width$}", s, width = width),
                "center" => format!("{:^width$}", s, width = width),
                _ => format!("{:>width$}", s, width = width),
            };
        }
    }

    format!("{}", num)
}

/// Format an integer according to format specifier
fn format_integer(num: i64, spec: &str) -> String {
    if spec.is_empty() {
        return format!("{}", num);
    }

    let spec = spec.trim_start_matches(':');

    // Check for number base
    match spec.chars().next() {
        Some('x') => return format!("{:x}", num),
        Some('X') => return format!("{:X}", num),
        Some('b') => return format!("{:b}", num),
        Some('o') => return format!("{:o}", num),
        Some('?') => {
            if spec == "#?" {
                return format!("{:#?}", num);
            }
            return format!("{:?}", num);
        }
        _ => {}
    }

    // Check for width and zero-padding
    if let Some('0') = spec.chars().next() {
        if let Ok(width) = spec[1..].parse::<usize>() {
            return format!("{:0width$}", num, width = width);
        }
    }

    // Check for alignment and width
    if let Some(first_char) = spec.chars().next() {
        let (align, rest) = match first_char {
            '<' => ("left", &spec[1..]),
            '^' => ("center", &spec[1..]),
            _ => ("right", spec),
        };

        if let Ok(width) = rest.parse::<usize>() {
            let s = format!("{}", num);
            return match align {
                "left" => format!("{:<width$}", s, width = width),
                "center" => format!("{:^width$}", s, width = width),
                _ => format!("{:>width$}", s, width = width),
            };
        }
    }

    format!("{}", num)
}

/// Format a string according to format specifier
fn format_string(s: &str, spec: &str) -> String {
    if spec.is_empty() {
        return s.to_string();
    }

    let spec = spec.trim_start_matches(':');

    // Check for debug formatting
    if spec == "?" {
        return format!("{:?}", s);
    } else if spec == "#?" {
        return format!("{:#?}", s);
    }

    // Check for alignment and width
    if let Some(first_char) = spec.chars().next() {
        let (align, rest) = match first_char {
            '<' => ("left", &spec[1..]),
            '^' => ("center", &spec[1..]),
            _ => ("right", spec),
        };

        if let Ok(width) = rest.parse::<usize>() {
            return match align {
                "left" => format!("{:<width$}", s, width = width),
                "center" => format!("{:^width$}", s, width = width),
                _ => format!("{:>width$}", s, width = width),
            };
        }
    }

    s.to_string()
}

/// context
pub struct Context {
    pub debug: bool,
    pub config: Option<std::sync::Arc<std::sync::Mutex<crate::config::Config>>>,
    pub args: Option<std::sync::Arc<std::sync::Mutex<crate::config::Arguments>>>,
    pub builtins: Option<crate::builtins::Builtins>,
    pub env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    pub vars: std::sync::Arc<
        std::sync::Mutex<std::collections::HashMap<String, crate::expressions::Expressions>>,
    >,
    pub aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    pub history: std::sync::Arc<std::sync::Mutex<crate::history::History>>,

    pub functions: std::collections::HashMap<String, crate::expressions::Expressions>,
    pub code: Vec<crate::expressions::Expressions>,
}

impl Context {
    /// return available builtins
    fn get_builtins(&self) -> Vec<crate::builtins::Builtin> {
        vec![
            // help
            crate::builtins::Builtin {
                name: "help".to_string(),
                description: "Display help information".to_string(),
                help: "Usage: help".to_string(),
                execute: Box::new(|_, _, _, _, _, _, builtin_names, _, _| {
                    println!("🐢 builtins:");
                    for name in builtin_names {
                        println!(" - {}", name);
                    }
                }),
            },
            // printf
            crate::builtins::Builtin {
                name: "printf".to_string(),
                description: "Print formatted output to the console".to_string(),
                help: r#"Usage: printf <format_string> [args...]
Format specifiers:
  {}       - default formatting
  {:?}     - debug formatting
  {:#?}    - pretty debug formatting
  {:x}     - lowercase hex
  {:X}     - uppercase hex
  {:b}     - binary
  {:o}     - octal
  {:.N}    - precision (N decimal places)
  {:N}     - minimum width (right-aligned)
  {:<N}    - left-aligned width
  {:^N}    - center-aligned width
  {:0N}    - zero-padded width
Examples:
  printf "Hello, {}!" "World"
  printf "Number: {:.2}" 3.14159
  printf "Hex: {:x}" 255
  printf "Binary: {:b}" 42"#
                    .to_string(),
                execute: Box::new(|_, _, _, _, _, _, _, args, _| {
                    if args.is_empty() {
                        eprintln!("printf: missing format string");
                        eprintln!("Usage: printf <format_string> [args...]");
                        return;
                    }

                    let format_str = &args[0];
                    let format_args = &args[1..];

                    // Parse format string and find placeholders
                    let mut result = String::new();
                    let mut chars = format_str.chars().peekable();
                    let mut arg_idx = 0;

                    while let Some(c) = chars.next() {
                        if c == '{' {
                            if let Some(&next_c) = chars.peek() {
                                if next_c == '{' {
                                    // Escaped brace: {{
                                    result.push('{');
                                    chars.next();
                                    continue;
                                }
                            }

                            // Parse format specifier
                            let mut spec = String::new();
                            while let Some(&c) = chars.peek() {
                                if c == '}' {
                                    chars.next();
                                    break;
                                }
                                spec.push(c);
                                chars.next();
                            }

                            // Get the argument
                            if arg_idx >= format_args.len() {
                                eprintln!("printf: not enough arguments for format string");
                                return;
                            }

                            let arg = &format_args[arg_idx];
                            arg_idx += 1;

                            // Try to parse as number first
                            let formatted = if let Ok(num) = arg.parse::<f64>() {
                                format_number(num, &spec)
                            } else if let Ok(num) = arg.parse::<i64>() {
                                format_integer(num, &spec)
                            } else {
                                format_string(arg, &spec)
                            };

                            result.push_str(&formatted);
                        } else if c == '}' {
                            if let Some(&next_c) = chars.peek() {
                                if next_c == '}' {
                                    // Escaped brace: }}
                                    result.push('}');
                                    chars.next();
                                    continue;
                                }
                            }
                            result.push(c);
                        } else {
                            result.push(c);
                        }
                    }

                    print!("{}\n", result);
                }),
            },
            // keywords
            crate::builtins::Builtin {
                name: "keywords".to_string(),
                description: "Display keywords".to_string(),
                help: "Usage: keywords".to_string(),
                execute: Box::new(|_, _, _, _, _, _, builtin_names, _, _| {
                    println!("🐢 keywords:");
                    for keyword in crate::lang::KEYWORDS {
                        println!(" - {}", keyword);
                    }
                }),
            },
            // timestamp
            crate::builtins::Builtin {
                name: "timestamp".to_string(),
                description: "Convert a timestamp to a date".to_string(),
                help: "Usage: timestamp <timestamp>".to_string(),
                execute: Box::new(|_, _, _, _, _, _, builtin_names, args, _| {
                    if args.is_empty() {
                        eprintln!("timestamp <timestamp>");
                        return;
                    }
                    let timestamp = &args[0];
                    let duration =
                        std::time::Duration::from_secs(timestamp.parse::<u64>().unwrap_or(0));
                    let datetime = std::time::UNIX_EPOCH + duration;
                    println!("DateTime: {:?}", datetime);
                }),
            },
            // imgcat
            crate::builtins::Builtin {
                name: "imgcat".to_string(),
                description: "display images".to_string(),
                help: "Usage: imgcat <image_path>".to_string(),
                execute: Box::new(|_, _, _, _, _, _, builtin_names, args, _| {
                    if args.is_empty() {
                        eprintln!("imgcat <image_path>");
                        return;
                    }
                    let image_path = &args[0];
                    // TODO: implement image display logic
                }),
            },
            // ast
            crate::builtins::Builtin {
                name: "ast".to_string(),
                description: "Translate a string to Turtle AST".to_string(),
                help: "Usage: ast <code>".to_string(),
                execute: Box::new(
                    |_, turtle_args, env, aliases, vars, _, builtin_names, args, debug| {
                        let code = args.join(" ");
                        // Evaluate the code
                        let mut interpreter = crate::lang::Interpreter::new(
                            Some(turtle_args.clone()),
                            env.clone(),
                            aliases.clone(),
                            vars.clone(),
                            builtin_names,
                            debug,
                        );

                        let _tokens = interpreter.tokenize(&code.as_str());
                        let expr = interpreter.interpret();
                        println!("turtle ast: {:?}", expr);
                    },
                ),
            },
            // tokenize
            crate::builtins::Builtin {
                name: "tokenize".to_string(),
                description: "Tokenize a string as Turtle code".to_string(),
                help: "Usage: tokenize <code>".to_string(),
                execute: Box::new(
                    |_, turtle_args, env, aliases, vars, _, builtin_names, args, debug| {
                        let code = args.join(" ");

                        // Evaluate the code
                        let mut interpreter = crate::lang::Interpreter::new(
                            Some(turtle_args.clone()),
                            env.clone(),
                            aliases.clone(),
                            vars.clone(),
                            builtin_names,
                            debug,
                        );

                        let tokens = interpreter.tokenize(&code.as_str());
                        println!("turtle tokens: {:?}", tokens);
                    },
                ),
            },
            // eval
            crate::builtins::Builtin {
                name: "eval".to_string(),
                description: "Evaluate a string as Turtle code".to_string(),
                help: "Usage: eval <code>".to_string(),
                execute: Box::new(
                    |config,
                     turtle_args,
                     env,
                     aliases,
                     vars,
                     history,
                     builtin_names,
                     args,
                     debug| {
                        if args.is_empty() {
                            eprintln!("eval <code>");
                            return;
                        }
                        let code = args.join(" ");
                        let mut interpreter = crate::lang::Interpreter::new(
                            Some(turtle_args.clone()),
                            env.clone(),
                            aliases.clone(),
                            vars.clone(),
                            builtin_names,
                            debug,
                        );
                        let mut context = crate::context::Context::new(
                            Some(config.clone()),
                            Some(turtle_args.clone()),
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
                    },
                ),
            },
            // history
            crate::builtins::Builtin {
                name: "history".to_string(),
                description: "Get and Manage command history".to_string(),
                help: "Usage: history".to_string(),
                execute: Box::new(|_, _, _, _, _, history, _, args, _| {
                    if args.is_empty() {
                        if let Some(events) = history.lock().unwrap().events.as_ref() {
                            for (i, event) in events.iter().enumerate() {
                                println!("{}: {:?}", i + 1, event);
                            }
                        } else {
                            println!("No history available.");
                        }
                    }
                    let arg_refs: Vec<&str> = args.iter().map(|s| s.as_str()).collect();

                    if arg_refs.contains(&"-h") || arg_refs.contains(&"--help") {
                        println!("history");
                        println!("Display command history.");
                        println!("Options:");
                        println!("  -c, --clear    Clear the command history.");
                        return;
                    }

                    if arg_refs.contains(&"-c") || arg_refs.contains(&"--clear") {
                        history.lock().unwrap().events = Some(vec![]);
                        println!("Command history cleared.");
                    }
                }),
            },
            // noop
            crate::builtins::Builtin {
                name: "noop".to_string(),
                description: "No operation builtin".to_string(),
                help: "Usage: noop".to_string(),
                execute: Box::new(|_, _, _, _, _, _, _, _, _| ()),
            },
            // exit
            crate::builtins::Builtin {
                name: "exit".to_string(),
                description: "Exit the turtle shell".to_string(),
                help: "Usage: exit".to_string(),
                execute: Box::new(|_, _, _, _, _, _, _, _, _| {
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
            crate::builtins::Builtin {
                name: "cd".to_string(),
                description: "Change the current directory".to_string(),
                help: "Usage: cd [directory]".to_string(),
                execute: Box::new(|_, _, _, _, _, _, _, args, _| {
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
            crate::builtins::Builtin {
                name: "alias".to_string(),
                description: "Manage command aliases".to_string(),
                help: "Usage: alias [name='command']".to_string(),
                execute: Box::new(|_, _, _, aliases, _, _, _, args, _| {
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
                            println!("alias set: {}='{}'", name, command);
                        } else {
                            eprintln!("invalid alias format. Use name='command'");
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
        self.builtins = Some(crate::builtins::Builtins {
            env: self.env.clone(),
            aliases: self.aliases.clone(),
            vars: self.vars.clone(),
            builtins,
            debug: self.debug,
        });
    }

    pub fn get_var(&self, name: &str) -> Option<crate::expressions::Expressions> {
        self.vars.lock().unwrap().get(name).cloned()
    }

    pub fn set_var(&mut self, name: String, value: crate::expressions::Expressions) {
        self.vars.lock().unwrap().insert(name, value);
    }

    pub fn get_env(&self, name: &str) -> Option<String> {
        self.env.lock().unwrap().get(name).cloned()
    }

    pub fn set_env(&mut self, name: String, value: String) {
        self.env.lock().unwrap().insert(name, value);
    }

    /// Evaluate environment variables: $```<Identifier>```
    fn eval_environment_variable(&mut self, name: &str) -> Option<crate::context::EvalResults> {
        let value = self.get_env(name);
        Some(
            crate::context::EvalResults::EnvironmentVariableExpressionResult(
                crate::context::EnvironmentVariableEvalResult {
                    name: name.to_string(),
                    value,
                },
            ),
        )
    }

    /// Evaluate binary operations: `left (<operator>) right`
    fn eval_binary_operation(
        &mut self,
        left: crate::expressions::Expressions,
        op: String,
        right: crate::expressions::Expressions,
    ) -> Option<crate::context::EvalResults> {
        if let Some(args) = &self.args {
            let args = args.lock().unwrap();
            if args.is_debugging() || args.should_debug_context() {
                println!(
                    "🔢 Evaluating binary operation: {:?} {} {:?}",
                    left, op, right
                );
            }
        }

        // Recursively evaluate left and right, handling nested BinaryOperation
        let left_result = match left {
            crate::expressions::Expressions::BinaryOperation { left, op, right } => {
                self.eval_binary_operation(*left, op, *right)?
            }
            _ => self.eval(Some(left))?,
        };

        let right_result = match right {
            crate::expressions::Expressions::BinaryOperation { left, op, right } => {
                self.eval_binary_operation(*left, op, *right)?
            }
            _ => self.eval(Some(right))?,
        };

        if let Some(args) = &self.args {
            let args = args.lock().unwrap();
            if args.is_debugging() || args.should_debug_context() {
                println!(
                    "🔢 Left result: {:?}, Right result: {:?}",
                    left_result, right_result
                );
            }
        }

        match (left_result, right_result) {
            (
                crate::context::EvalResults::NumberExpressionResult(left_num),
                crate::context::EvalResults::NumberExpressionResult(right_num),
            ) => {
                let result = match op.as_str() {
                    "+" => left_num.value + right_num.value,
                    "-" => left_num.value - right_num.value,
                    "*" => left_num.value * right_num.value,
                    "/" => left_num.value / right_num.value,
                    "%" => left_num.value % right_num.value,
                    _ => {
                        eprintln!("unsupported operation: {}", op);
                        return None;
                    }
                };
                Some(crate::context::EvalResults::NumberExpressionResult(
                    crate::context::NumberEvalResult { value: result },
                ))
            }
            (
                crate::context::EvalResults::StringExpressionResult(left_str),
                crate::context::EvalResults::StringExpressionResult(right_str),
            ) => {
                if op == "+" {
                    let result = format!("{}{}", left_str.value, right_str.value);
                    Some(crate::context::EvalResults::StringExpressionResult(
                        crate::context::StringEvalResult { value: result },
                    ))
                } else {
                    eprintln!("unsupported operation for strings: {}", op);
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
        value: crate::expressions::Expressions,
    ) -> Option<crate::context::EvalResults> {
        // Check if the variable name conflicts with a builtin
        if let Some(ref builtins) = self.builtins {
            if builtins.list().contains(&name) {
                let warning = format!(
                    "Warning: Variable '{}' shadows builtin command. Use a different name.",
                    name
                );
                eprintln!("{}", warning);
                return Some(crate::context::EvalResults::StringExpressionResult(
                    crate::context::StringEvalResult { value: warning },
                ));
            }
        }

        // Check if the variable name conflicts with a shell command
        if crate::utils::is_command(&name) {
            let warning = format!(
                "Warning: Variable '{}' shadows shell command. Use a different name.",
                name
            );
            eprintln!("{}", warning);
            return Some(crate::context::EvalResults::StringExpressionResult(
                crate::context::StringEvalResult { value: warning },
            ));
        }

        let _evaluated_value = self.eval(Some(value.clone()))?;

        // Store the variable in the context
        self.vars
            .lock()
            .unwrap()
            .insert(name.clone(), value.clone());

        // Return an AssignmentResult
        Some(crate::context::EvalResults::AssignmentExpressionResult(
            crate::context::AssignmentEvalResult { name, value },
        ))
    }

    /// Evaluate variable access: ```<Identifier>```
    fn eval_variable_access(
        &mut self,
        name: &str,
        value: Box<crate::expressions::Expressions>,
    ) -> Option<crate::context::EvalResults> {
        // get the variables values - this is an expression
        let var = {
            let vars = self.vars.lock().unwrap();
            vars.get(name)?.clone()
        };

        let results = self.eval(Some(var.clone()))?;

        return Some(results);
    }

    fn _eval_binary_operation_deprecated(
        &mut self,
        left: crate::expressions::Expressions,
        op: String,
        right: crate::expressions::Expressions,
    ) -> Option<crate::context::EvalResults> {
        // we need to handle chained operations

        let left = self.eval(Some(left))?;
        let operation = op;
        let right = self.eval(Some(right))?;

        match (left, right) {
            (
                crate::context::EvalResults::NumberExpressionResult(left_num),
                crate::context::EvalResults::NumberExpressionResult(right_num),
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
                return Some(crate::context::EvalResults::NumberExpressionResult(
                    crate::context::NumberEvalResult { value: result },
                ));
            }

            // support adding strings for concatenation
            (
                crate::context::EvalResults::StringExpressionResult(left_str),
                crate::context::EvalResults::StringExpressionResult(right_str),
            ) => {
                if operation == "+" {
                    let result = format!("{}{}", left_str.value, right_str.value);
                    return Some(crate::context::EvalResults::StringExpressionResult(
                        crate::context::StringEvalResult { value: result },
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

    fn eval_builtin(&mut self, name: &str, args: &str) -> Option<crate::context::EvalResults> {
        let env = self.env.clone();
        let aliases = self.aliases.clone();
        let vars = self.vars.clone();
        let history = self.history.clone();

        if let Some(ref builtins) = self.builtins {
            let builtin_names = builtins.list();
            let builtin = builtins.get(name)?;
            let arg_vec: Vec<String> = args.split_whitespace().map(|s| s.to_string()).collect();

            // check debugging config
            let debug = {
                if let Some(args) = &self.args {
                    let args = args.lock().unwrap();
                    args.is_debugging() || args.should_debug_context()
                } else {
                    false
                }
            };

            let result = (builtin.execute)(
                self.config.clone().unwrap(),
                self.args.clone().unwrap(),
                env,
                aliases,
                vars,
                history,
                builtin_names,
                arg_vec,
                debug,
            );
            return Some(crate::context::EvalResults::BuiltinExpressionResult(
                crate::context::BuiltinEvalResult {
                    output: Some(format!("{:?}", result)),
                },
            ));
        }
        None
    }

    fn eval_spawn_command(
        &mut self,
        command: &str,
        args: &str,
    ) -> Option<crate::context::EvalResults> {
        use std::process::Command;
        let args_vec: Vec<&str> = args.split_whitespace().collect();

        // construct a command request
        let id = uuid::Uuid::new_v4().to_string();
        let command_request = crate::history::CommandRequest {
            id: id.clone(),
            command: command.to_string(),
            args: args_vec.iter().map(|s| s.to_string()).collect(),
            timestamp: crate::utils::now_unix(),
            // event: "command_request".to_string(),
        };

        let mut gaurd = self.history.lock().unwrap();

        let events = gaurd.events.as_mut();

        if let Some(events) = events {
            events.push(crate::history::Event::CommandRequest(command_request));
        }

        // self.history
        //     .lock()
        //     .unwrap()
        //     .events
        //     .as_mut()
        //     .push(crate::history::Event::CommandRequest(command_request));

        let mut child = Command::new(command)
            .args(&args_vec)
            .stdin(std::process::Stdio::inherit())
            .stdout(std::process::Stdio::piped())
            .stderr(std::process::Stdio::piped())
            .spawn()
            .ok()?;

        let mut stdout = String::new();
        if let Some(mut out) = child.stdout.take() {
            use std::io::Read;
            let _ = out.read_to_string(&mut stdout).ok();
        }

        let mut stderr = String::new();
        if let Some(mut err) = child.stderr.take() {
            use std::io::Read;
            let _ = err.read_to_string(&mut stderr).ok();
        }

        let code = child.wait().ok()?.code().unwrap_or(-1);
        let output = stdout;
        let errors = stderr;

        let command_response = crate::history::CommandResponse {
            id: id.clone(),
            status: "completed".to_string(),
            code,
            output: output.clone(),
            errors: errors.clone(),
            timestamp: crate::utils::now_unix(),
        };

        let mut gaurd = self.history.lock().unwrap();
        if let Some(event) = gaurd.events.as_mut() {
            event.push(crate::history::Event::CommandResponse(command_response));
        }

        Some(crate::context::EvalResults::CommandExpressionResult(
            crate::context::CommandEvalResult {
                stdout: output,
                stderr: errors,
                code,
            },
        ))
    }

    fn eval_exec_command(
        &mut self,
        command: &str,
        args: &str,
    ) -> Option<crate::context::EvalResults> {
        use std::process::Command;
        let args_vec: Vec<&str> = args.split_whitespace().collect();

        // construct a command request
        let id = uuid::Uuid::new_v4().to_string();
        let command_request = crate::history::CommandRequest {
            id: id.clone(),
            command: command.to_string(),
            args: args_vec.iter().map(|s| s.to_string()).collect(),
            timestamp: crate::utils::now_unix(),
        };

        // if let Some(history) = self.history.lock().unwrap() {
        //     history.add(crate::history::Event::CommandRequest(command_request));
        // }

        if let Some(gaurd) = self.history.lock().ok() {
            let mut history = gaurd;

            history.add(crate::history::Event::CommandRequest(
                command_request.clone(),
            ));
        }

        // if let Some(events) = self.history.lock().unwrap().events.as_mut() {
        //     events.push(crate::history::Event::CommandRequest(command_request));
        // }

        let exec_result = Command::new(command)
            .args(&args_vec)
            .stdin(std::process::Stdio::inherit())
            .output();

        match exec_result {
            Ok(output) => {
                let stdout = String::from_utf8_lossy(&output.stdout);
                let stderr = String::from_utf8_lossy(&output.stderr);
                let code = output.status.code().unwrap_or(-1);
                let result = crate::context::CommandEvalResult {
                    stdout: stdout.to_string(),
                    stderr: stderr.to_string(),
                    code,
                };
                let command_response = crate::history::CommandResponse {
                    id: id.clone(),
                    status: "completed".to_string(),
                    code,
                    output: stdout.to_string(),
                    errors: stderr.to_string(),
                    timestamp: crate::utils::now_unix(),
                };

                // self.history.add
                // append to history
                self.history
                    .lock()
                    .unwrap()
                    .events
                    .as_mut()
                    .unwrap()
                    .push(crate::history::Event::CommandResponse(command_response));

                // write to history

                // returns the command result
                Some(crate::context::EvalResults::CommandExpressionResult(result))
            }
            Err(e) => {
                eprintln!("failed to execute command: {}", e);
                None
            }
        }
    }

    pub fn new(
        config: Option<std::sync::Arc<std::sync::Mutex<crate::config::Config>>>,
        args: Option<std::sync::Arc<std::sync::Mutex<crate::config::Arguments>>>,
        env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        vars: std::sync::Arc<
            std::sync::Mutex<std::collections::HashMap<String, crate::expressions::Expressions>>,
        >,
        history: std::sync::Arc<std::sync::Mutex<crate::history::History>>,
        debug: bool,
    ) -> Self {
        if debug {
            // NOTE: adds an extra space
            println!("🛠️ initializing Context...");
        }
        Context {
            builtins: None,
            config,
            args,
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
        expr: Option<crate::expressions::Expressions>,
    ) -> Option<crate::context::EvalResults> {
        if let Some(ref e) = expr {
            self.code.push(e.clone());
        }
        match expr {
            // check if the expression is an Identifier and the identifier exists in vars

            // handle literal values
            Some(crate::expressions::Expressions::Assignment { name, value }) => {
                self.eval_assignment(name, value.as_ref().clone())
            }

            // experimental variable access
            Some(crate::expressions::Expressions::TurtleVariable { name, value }) => {
                self.eval_variable_access(&name, value)
            }

            Some(crate::expressions::Expressions::BinaryOperation { left, op, right }) => {
                let result = self.eval_binary_operation(*left, op, *right);

                if let Some(crate::context::EvalResults::NumberExpressionResult(n)) = &result {
                    println!("{}", n.value);
                }
                result
            }
            Some(crate::expressions::Expressions::Number(value)) => {
                Some(crate::context::EvalResults::NumberExpressionResult(
                    crate::context::NumberEvalResult { value },
                ))
            }
            Some(crate::expressions::Expressions::String(value)) => {
                Some(crate::context::EvalResults::StringExpressionResult(
                    crate::context::StringEvalResult { value },
                ))
            }
            Some(crate::expressions::Expressions::Boolean(value)) => {
                Some(crate::context::EvalResults::BooleanExpressionResult(
                    crate::context::BooleanEvalResult { value },
                ))
            }
            Some(crate::expressions::Expressions::Array(values)) => {
                let evaluated_values: Vec<crate::expressions::Expressions> = values
                    .into_iter()
                    .filter_map(|v| {
                        self.eval(Some(v.clone())).and_then(|res| match res {
                            crate::context::EvalResults::NumberExpressionResult(n) => {
                                Some(crate::expressions::Expressions::Number(n.value))
                            }
                            crate::context::EvalResults::StringExpressionResult(s) => {
                                Some(crate::expressions::Expressions::String(s.value))
                            }
                            crate::context::EvalResults::BooleanExpressionResult(b) => {
                                Some(crate::expressions::Expressions::Boolean(b.value))
                            }
                            // // allow objects
                            // crate::context::EvalResults::ObjectExpressionResult(o) => {
                            //     Some(crate::expressions::Expressions::Object(o.value))
                            // }
                            _ => None,
                        })
                    })
                    .collect();

                Some(crate::context::EvalResults::ArrayExpressionResult(
                    crate::context::ArrayEvalResult {
                        value: evaluated_values,
                    },
                ))
            }

            Some(crate::expressions::Expressions::Identifier(name)) => {
                // Check if it's a variable in the vars store
                let var_value = {
                    let vars = self.vars.lock().unwrap();
                    if let Some(args) = &self.args {
                        let args = args.lock().unwrap();
                        if args.debug {
                            println!("🔍 Looking up variable '{}' in vars", name);
                            println!("🔍 Current vars: {:?}", vars);
                        }
                    }

                    vars.get(&name).cloned()
                };

                if let Some(var_value) = var_value {
                    // Return the variable's value by evaluating it
                    let result = self.eval(Some(var_value.clone()));
                    if let Some(args) = &self.args {
                        let args = args.lock().unwrap();
                        if args.debug {
                            println!("🛠️ Evaluated variable '{}' to: {:?}", name, result);
                        }
                    }

                    result
                } else {
                    // Variable not found - return an error message instead of None
                    eprintln!("Error: Variable '{}' not defined", name);
                    Some(crate::context::EvalResults::StringExpressionResult(
                        crate::context::StringEvalResult {
                            value: format!("Error: Variable '{}' not defined", name),
                        },
                    ))
                }

                // let vars = self.vars.lock().unwrap();

                // if let Some(var_value) = vars.get(&name) {
                //     // Return the variable's value by evaluating it
                //     drop(vars); // Release the lock before recursive eval
                //     self.eval(Some(var_value.clone()))
                // } else {
                //     // Variable not found
                //     eprintln!("Error: Variable '{}' not defined", name);
                //     None
                // }
            }

            Some(crate::expressions::Expressions::EnvironmentVariable { name }) => {
                self.eval_environment_variable(&name)
            }

            Some(crate::expressions::Expressions::Builtin { name, args }) => {
                let result = self.eval_builtin(&name, &args);
                result
            }

            Some(crate::expressions::Expressions::ShellCommand { name, args }) => {
                let result = self.eval_exec_command(&name, &args);
                // result is an option, we need to unwrap it to access the code
                // the result is in the CommandResult variant of ShellResults
                if let Some(crate::context::EvalResults::CommandExpressionResult(cmd)) = &result {
                    if cmd.code != 0 {
                        eprintln!("{}", cmd.stderr);
                    } else {
                        print!("{}", cmd.stdout);
                    }
                }
                result
            }
            _ => {
                println!("evaluating expression: {:?}", expr);
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
    pub value: std::collections::HashMap<String, crate::expressions::Expressions>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ArrayEvalResult {
    pub value: Vec<crate::expressions::Expressions>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct AssignmentEvalResult {
    pub name: String,
    pub value: crate::expressions::Expressions,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct EnvironmentVariableEvalResult {
    pub name: String,
    pub value: Option<String>, // value can be None if the variable is not set
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TurtleVariableEvalResult {
    pub name: String,
    pub value: crate::expressions::Expressions,
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

impl std::fmt::Display for EvalResults {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
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
