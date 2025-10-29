#[derive(Debug, Clone)]
pub struct TurtleExecutionContext {
    pub env: std::collections::HashMap<String, String>,
    pub vars: std::collections::HashMap<String, crate::types::TurtleExpression>,
    pub functions: std::collections::HashMap<String, crate::types::TurtleExpression>,
    pub code: Vec<crate::types::TurtleExpression>,
    // pub
}

impl TurtleExecutionContext {
    pub fn get_var(&self, name: &str) -> Option<crate::types::TurtleExpression> {
        self.vars.get(name).cloned()
    }

    pub fn get_env(&self, name: &str) -> Option<String> {
        self.env.get(name).cloned()
    }

    pub fn set_env(&mut self, name: String, value: String) {
        self.env.insert(name, value);
    }

    fn eval_environment_variable(&mut self, name: &str) -> Option<crate::types::TurtleResults> {
        let value = self.get_env(name);
        Some(crate::types::TurtleResults::EnvironmentVariableResult(
            crate::types::EnvironmentVariableResult {
                name: name.to_string(),
                value,
            },
        ))
    }

    fn eval_binary_operation(
        &mut self,
        left: crate::types::TurtleExpression,
        op: String,
        right: crate::types::TurtleExpression,
    ) -> Option<crate::types::TurtleResults> {
        // Recursively evaluate left and right, handling nested BinaryOperation
        let left_result = match left {
            crate::types::TurtleExpression::BinaryOperation { left, op, right } => {
                self.eval_binary_operation(*left, op, *right)?
            }
            _ => self.eval(Some(left))?,
        };

        let right_result = match right {
            crate::types::TurtleExpression::BinaryOperation { left, op, right } => {
                self.eval_binary_operation(*left, op, *right)?
            }
            _ => self.eval(Some(right))?,
        };

        match (left_result, right_result) {
            (
                crate::types::TurtleResults::NumberResult(left_num),
                crate::types::TurtleResults::NumberResult(right_num),
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
                Some(crate::types::TurtleResults::NumberResult(
                    crate::types::NumberResult { value: result },
                ))
            }
            (
                crate::types::TurtleResults::StringResult(left_str),
                crate::types::TurtleResults::StringResult(right_str),
            ) => {
                if op == "+" {
                    let result = format!("{}{}", left_str.value, right_str.value);
                    Some(crate::types::TurtleResults::StringResult(
                        crate::types::StringResult { value: result },
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

    fn eval_assignment(
        &mut self,
        name: String,
        value: crate::types::TurtleExpression,
    ) -> Option<crate::types::TurtleResults> {
        // Evaluate the value expression
        let _evaluated_value = self.eval(Some(value.clone()))?;

        // Store the variable in the context
        println!("Assigning variable: {} = {:?}", name, value);
        self.vars.insert(name.clone(), value.clone());

        // Return an AssignmentResult
        Some(crate::types::TurtleResults::AssignmentResult(
            crate::types::AssignmentResult { name, value },
        ))
    }

    fn _eval_binary_operation_deprecated(
        &mut self,
        left: crate::types::TurtleExpression,
        op: String,
        right: crate::types::TurtleExpression,
    ) -> Option<crate::types::TurtleResults> {
        // we need to handle chained operations

        let left = self.eval(Some(left))?;
        let operation = op;
        let right = self.eval(Some(right))?;

        match (left, right) {
            (
                crate::types::TurtleResults::NumberResult(left_num),
                crate::types::TurtleResults::NumberResult(right_num),
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
                return Some(crate::types::TurtleResults::NumberResult(
                    crate::types::NumberResult { value: result },
                ));
            }

            // support adding strings for concatenation
            (
                crate::types::TurtleResults::StringResult(left_str),
                crate::types::TurtleResults::StringResult(right_str),
            ) => {
                if operation == "+" {
                    let result = format!("{}{}", left_str.value, right_str.value);
                    return Some(crate::types::TurtleResults::StringResult(
                        crate::types::StringResult { value: result },
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

    fn eval_builtin(&mut self, name: &str, args: &str) -> Option<crate::types::TurtleResults> {
        let builtin = crate::builtin::TurtleBuiltin::get(name)?;
        let arg_vec: Vec<String> = args.split_whitespace().map(|s| s.to_string()).collect();
        let result = (builtin.execute)(arg_vec);
        Some(crate::types::TurtleResults::BuiltinResult(
            crate::types::BuiltinResult {
                output: Some(format!("{:?}", result)),
            },
        ))
    }

    fn eval_command(&mut self, command: &str, args: &str) -> Option<crate::types::TurtleResults> {
        use std::process::Command;
        let args_vec: Vec<&str> = args.split_whitespace().collect();
        let exec_result = Command::new(command)
            .args(&args_vec)
            .stdin(std::process::Stdio::inherit())
            .output();

        match exec_result {
            Ok(output) => {
                let stdout = String::from_utf8_lossy(&output.stdout);
                let stderr = String::from_utf8_lossy(&output.stderr);
                let code = output.status.code().unwrap_or(-1);
                let result = crate::types::ShellCommandResult {
                    stdout: stdout.to_string(),
                    stderr: stderr.to_string(),
                    code,
                };
                Some(crate::types::TurtleResults::CommandResult(result))
            }
            Err(e) => {
                eprintln!("Failed to execute command: {}", e);
                None
            }
        }
    }

    pub fn new() -> Self {
        TurtleExecutionContext {
            env: std::collections::HashMap::new(),
            vars: std::collections::HashMap::new(),
            functions: std::collections::HashMap::new(),
            code: Vec::new(),
        }
    }

    pub fn eval(
        &mut self,
        expr: Option<crate::types::TurtleExpression>,
    ) -> Option<crate::types::TurtleResults> {
        // self.code.push(expr.unwrap().clone());
        if let Some(ref e) = expr {
            self.code.push(e.clone());
        }
        match expr {
            // handle literal values
            Some(crate::types::TurtleExpression::Assignment { name, value }) => {
                self.eval_assignment(name, value.as_ref().clone())
            }
            Some(crate::types::TurtleExpression::BinaryOperation { left, op, right }) => {
                let result = self.eval_binary_operation(*left, op, *right);

                if let Some(crate::types::TurtleResults::NumberResult(n)) = &result {
                    println!("{}", n.value);
                }
                result
            }
            Some(crate::types::TurtleExpression::Number(value)) => Some(
                crate::types::TurtleResults::NumberResult(crate::types::NumberResult { value }),
            ),
            Some(crate::types::TurtleExpression::String(value)) => {
                println!("evaluated string: {}", value);
                Some(crate::types::TurtleResults::StringResult(
                    crate::types::StringResult { value },
                ))
            }
            Some(crate::types::TurtleExpression::Boolean(value)) => Some(
                crate::types::TurtleResults::BooleanResult(crate::types::BooleanResult { value }),
            ),
            Some(crate::types::TurtleExpression::Array(values)) => {
                let evaluated_values: Vec<crate::types::TurtleExpression> = values
                    .into_iter()
                    .filter_map(|v| {
                        self.eval(Some(v.clone())).and_then(|res| match res {
                            crate::types::TurtleResults::NumberResult(n) => {
                                Some(crate::types::TurtleExpression::Number(n.value))
                            }
                            crate::types::TurtleResults::StringResult(s) => {
                                Some(crate::types::TurtleExpression::String(s.value))
                            }
                            crate::types::TurtleResults::BooleanResult(b) => {
                                Some(crate::types::TurtleExpression::Boolean(b.value))
                            }
                            _ => None,
                        })
                    })
                    .collect();

                Some(crate::types::TurtleResults::ArrayResult(
                    crate::types::ArrayResult {
                        value: evaluated_values,
                    },
                ))
            }

            Some(crate::types::TurtleExpression::EnvironmentVariable { name }) => {
                self.eval_environment_variable(&name)
            }

            Some(crate::types::TurtleExpression::Builtin { name, args }) => {
                let result = self.eval_builtin(&name, &args);
                // println!("Builtin {} executed with result: {:?}", name, result);
                result
            }

            Some(crate::types::TurtleExpression::ShellCommand { name, args }) => {
                let result = self.eval_command(&name, &args);
                // result is an option, we need to unwrap it to access the code
                // the result is in the CommandResult variant of ShellResults
                if let Some(crate::types::TurtleResults::CommandResult(cmd)) = &result {
                    if cmd.code != 0 {
                        eprintln!("{}", cmd.stderr);
                    } else {
                        print!("{}", cmd.stdout);
                    }
                }

                // println!("{} executed with result: {:?}", name, result);
                result
            }
            _ => {
                println!("Evaluating expression: {:?}", expr);
                None
            }
        }
    }
}
