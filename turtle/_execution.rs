/// execution context
pub struct Context {
    pub builtins: Option<crate::types::Builtins>,
    pub env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    pub vars: std::sync::Arc<
        std::sync::Mutex<std::collections::HashMap<String, crate::types::Expressions>>,
    >,
    pub aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    pub history: std::sync::Arc<std::sync::Mutex<Vec<crate::types::HistoryEvent>>>,
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
                execute: Box::new(|env, aliases, vars, _, builtin_names, args| {
                    let code = args.join(" ");
                    // Evaluate the code
                    let mut interpreter = crate::interpreter::Tokenizer::new(
                        env.clone(),
                        aliases.clone(),
                        vars.clone(),
                        builtin_names,
                    );

                    let _tokens = interpreter.tokenize(&code.as_str());
                    let expr = interpreter.interpret();
                    println!("ast: {:?}", expr);
                }),
            },
            crate::types::Builtin {
                name: "tokenize".to_string(),
                description: "Tokenize a string as Turtle code".to_string(),
                help: "Usage: tokenize <code>".to_string(),
                execute: Box::new(|env, aliases, vars, _, builtin_names, args| {
                    let code = args.join(" ");

                    // Evaluate the code
                    let mut interpreter = crate::interpreter::Tokenizer::new(
                        env.clone(),
                        aliases.clone(),
                        vars.clone(),
                        builtin_names,
                    );

                    let tokens = interpreter.tokenize(&code.as_str());
                    println!("tokens: {:?}", tokens);
                }),
            },
            crate::types::Builtin {
                name: "eval".to_string(),
                description: "Evaluate a string as Turtle code".to_string(),
                help: "Usage: eval <code>".to_string(),
                execute: Box::new(|env, aliases, vars, history, builtin_names, args| {
                    if args.is_empty() {
                        eprintln!("Usage: eval <code>");
                        return;
                    }

                    // we need to collect the arguments into a single code string
                    let code = args.join(" ");
                    // Evaluate the code
                    let mut interpreter = crate::interpreter::Tokenizer::new(
                        env.clone(),
                        aliases.clone(),
                        vars.clone(),
                        builtin_names,
                    );
                    let mut context = crate::context::Context::new(
                        env.clone(),
                        aliases.clone(),
                        vars.clone(),
                        history.clone(),
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
                execute: Box::new(|_, _, _, history, _, args| {
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
                execute: Box::new(|_, _, _, _, _, _| ()),
            },
            crate::types::Builtin {
                name: "exit".to_string(),
                description: "Exit the turtle shell".to_string(),
                help: "Usage: exit".to_string(),
                execute: Box::new(|_, _, _, _, _, _| {
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
                execute: Box::new(|_, _, _, _, _, args| {
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
                execute: Box::new(|_, aliases, _, _, _, args| {
                    let arg_refs: Vec<&str> = args.iter().map(|s| s.as_str()).collect();

                    // if no args, list aliases
                    if args.is_empty() {
                        let aliases_lock = aliases.lock().unwrap();
                        for (name, command) in aliases_lock.iter() {
                            println!("alias {}='{}'", name, command);
                        }
                        return;
                    }

                    // args contains '-h' or '--help'
                    if arg_refs.contains(&"-h") || arg_refs.contains(&"--help") {
                        println!("Usage: alias [name='command']");
                        println!("Create or display command aliases.");
                        println!("If no arguments are provided, lists all aliases.");
                        return;
                    }

                    // mock bash/zsh alias behavior
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
        });
    }

    pub fn get_var(&self, name: &str) -> Option<crate::types::Expressions> {
        self.vars.lock().unwrap().get(name).cloned()
    }

    #[allow(dead_code)]
    pub fn set_var(&mut self, name: String, value: crate::types::Expressions) {
        self.vars.lock().unwrap().insert(name, value);
    }

    #[allow(dead_code)]
    pub fn get_env(&self, name: &str) -> Option<String> {
        self.env.lock().unwrap().get(name).cloned()
    }

    #[allow(dead_code)]
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
                    // eprintln!("Unsupported operation for strings: {}", operation);
                    return None;
                }
            }
            _ => {
                // eprintln!("Binary operations are only supported for numbers currently.");
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
            let result = (builtin.execute)(env, aliases, vars, history, builtin_names, arg_vec);
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
            .push(crate::types::HistoryEvent::CommandRequest(command_request));

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
                    .push(crate::types::HistoryEvent::CommandResponse(
                        command_response,
                    ));
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
        history: std::sync::Arc<std::sync::Mutex<Vec<crate::types::HistoryEvent>>>,
    ) -> Self {
        Context {
            builtins: None,
            env,
            vars,
            aliases,
            history,
            functions: std::collections::HashMap::new(),
            code: Vec::new(),
        }
    }

    pub fn eval(
        &mut self,
        expr: Option<crate::types::Expressions>,
    ) -> Option<crate::types::EvalResults> {
        // self.code.push(expr.unwrap().clone());
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
                // println!("Builtin {} executed with result: {:?}", name, result);
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
