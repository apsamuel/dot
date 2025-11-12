use serde::{Deserialize, Serialize};

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
    pub history: std::sync::Arc<std::sync::Mutex<Vec<crate::history::Event>>>,
    pub functions: std::collections::HashMap<String, crate::expressions::Expressions>,
    pub code: Vec<crate::expressions::Expressions>,
}

impl Context {
    /// return available builtins
    fn get_builtins(&self) -> Vec<crate::builtins::Builtin> {
        vec![
            crate::builtins::Builtin {
                name: "ast".to_string(),
                description: "Translate a string to Turtle AST".to_string(),
                help: "Usage: ast <code>".to_string(),
                execute: Box::new(|_, _, env, aliases, vars, _, builtin_names, args, debug| {
                    let code = args.join(" ");
                    // Evaluate the code
                    let mut interpreter = crate::lang::Interpreter::new(
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
            crate::builtins::Builtin {
                name: "tokenize".to_string(),
                description: "Tokenize a string as Turtle code".to_string(),
                help: "Usage: tokenize <code>".to_string(),
                execute: Box::new(|_, _, env, aliases, vars, _, builtin_names, args, debug| {
                    let code = args.join(" ");

                    // Evaluate the code
                    let mut interpreter = crate::lang::Interpreter::new(
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
            crate::builtins::Builtin {
                name: "history".to_string(),
                description: "Get and Manage command history".to_string(),
                help: "Usage: history".to_string(),
                execute: Box::new(|_, _, _, _, _, history, _, args, _| {
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
            crate::builtins::Builtin {
                name: "noop".to_string(),
                description: "No operation builtin".to_string(),
                help: "Usage: noop".to_string(),
                execute: Box::new(|_, _, _, _, _, _, _, _, _| ()),
            },
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
            let debug = self.debug;
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

        self.history
            .lock()
            .unwrap()
            .push(crate::history::Event::CommandRequest(command_request));

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

        self.history
            .lock()
            .unwrap()
            .push(crate::history::Event::CommandResponse(command_response));

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
            // event: "command_request".to_string(),
        };

        self.history
            .lock()
            .unwrap()
            .push(crate::history::Event::CommandRequest(command_request));

        let exec_result = Command::new(command)
            .args(&args_vec)
            .stdin(std::process::Stdio::inherit())
            .output();

        // let spawn_result = Command::new(command)
        //     .args(&args_vec)
        //     .stdin(std::process::Stdio::inherit())
        //     .spawn();

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
                self.history
                    .lock()
                    .unwrap()
                    .push(crate::history::Event::CommandResponse(command_response));
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
        history: std::sync::Arc<std::sync::Mutex<Vec<crate::history::Event>>>,
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
