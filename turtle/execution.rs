#[derive(Debug, Clone)]
pub struct TurtleExecutionContext {
    pub env: std::collections::HashMap<String, String>,
    pub vars: std::collections::HashMap<String, crate::types::TurtleExpression>,
    pub functions: std::collections::HashMap<String, crate::types::TurtleExpression>,
    pub code_stack: Vec<crate::types::TurtleExpression>,
    // pub
}

impl TurtleExecutionContext {
    fn execute_command(&mut self, command: &str, args: &str) {
        use std::process::Command;
        println!("Executing command: {} with args: {}", command, args);
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
                println!("Command exited with code: {}", code);
                if !stdout.is_empty() {
                    println!("Stdout:\n{}", stdout);
                }
                if !stderr.is_empty() {
                    eprintln!("Stderr:\n{}", stderr);
                }
            }
            Err(e) => {
                eprintln!("Failed to execute command: {}", e);
            }
        }
    }

    pub fn new() -> Self {
        TurtleExecutionContext {
            env: std::collections::HashMap::new(),
            vars: std::collections::HashMap::new(),
            functions: std::collections::HashMap::new(),
            code_stack: Vec::new(),
        }
    }

    pub fn eval(&mut self, expr: Option<crate::types::TurtleExpression>) {
        match expr {
            Some(crate::types::TurtleExpression::ShellCommand { name, args }) => {
                self.execute_command(&name, &args);
            }
            _ => {
                println!("Evaluating expression: {:?}", expr);
            }
        }
    }
}
