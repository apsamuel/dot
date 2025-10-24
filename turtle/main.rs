mod config; // configuration loading and environment setup
mod input; // input handling (env var and tilde expansion)
mod history; // command history logging
mod utils; // utility functions
mod types; // shared structs/enums
mod interpreter; // turtle shell interpreter
mod shell ; // main shell struct

mod builtin; // built-in commands
mod widgets; // TUI widgets
mod themes; // theme management

mod prompt; // prompt handling

use clap::Parser; // command line argument parsing
use std::process::{Command, Stdio}; // command execution
use uuid::Uuid; // unique ID generation
use rustyline::config::{Config, EditMode};  // readline configuration
use rustyline::{DefaultEditor as Editor}; // readline editor configuration

use crate::config::{load_config, set_shell_vars}; // config functions
use crate::input::{expand_env_vars, expand_tilde, expand_single_dot, expand_double_dot}; // input expansion
use crate::history::{log_history}; // history logging
use crate::utils::{now_unix}; // utility functions
use crate::types::{CommandRequest, CommandResponse, TurtleArgs};    // shared types
use crate::prompt::{expand_prompt_macros}; // prompt handling

#[tokio::main]
async fn main() {
    // test_parser();
    let mut turtle_intepreter = crate::interpreter::TurtleInterpreter::new();
    let _start_time = now_unix();
    let mut aliases: std::collections::HashMap<String, String> = std::collections::HashMap::new();
    let _pid = std::process::id();
    let turtle_args = TurtleArgs::parse();
    let config = load_config(
        turtle_args.debug
    );
    let turtle_shell = crate::shell::TurtleShell::new(
        config.clone().unwrap_or(crate::types::TurtleConfig {
            debug: false,
            prompt: None,
            aliases: None,
            history_size: None,
            theme: None,
        }),
        turtle_args.clone(),
        turtle_intepreter.clone(),
        turtle_args.debug,
    );
    let turtle_theme = std::env::var("TURTLE_THEME").unwrap_or_else(|_| "solarized_dark".into());
    let prompt = if let Some(cfg) = &config {
        cfg.prompt.clone().unwrap_or_else(|| "turtle> ".to_string())
    } else {
        "turtle> ".to_string()
    };

    // check if a command was provided for non-interactive mode
    if let Some(cmd) = &turtle_args.command {
        // non-interactive mode
        // gather tokens for input
        turtle_intepreter.reset();
        let tokens = turtle_intepreter.tokenize(&cmd);
        let expression = turtle_intepreter.interpret();

        // let tokens = turtle_intepreter.tokenize_shell_tertiary(tokens);
        // let tokens = turtle_intepreter.tokenize_secondary(tokens);
        println!("Input Tokens: {:?}", tokens);
        println!("Interpreted Expression: {:?}", expression);

        let id = Uuid::new_v4().to_string();
        let request = CommandRequest {
            id: id.clone(),
            command: cmd.clone(),
            args: vec![],
            timestamp: now_unix(),
            event: "command_request".to_string(),
        };
        let mut command  = Command::new("sh"); // for now we are not using execve to run commands directly
        command.arg("-c").arg(cmd);
        command.stdin(Stdio::inherit());
        let output = command.output().expect("Failed to execute command");
        let status_code = match output.status.code() {
            Some(code) => code,
            None => {
                eprintln!("Command terminated by signal");
                1
            }
        };
        let output_status = output.status;
        let stdout = String::from_utf8_lossy(&output.stdout).to_string();
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();
        let status = output.status;

        let response = crate::types::CommandResponse {
            id: Uuid::new_v4().to_string(),
            status: "done".to_string(),
            code: status_code,
            output: stdout.clone(),
            errors: stderr.clone(),
            timestamp: now_unix(),
            event: "command_response".to_string(),
        };

        if let Some(output_type) = &turtle_args.format {
            let result = crate::types::TurtleOutputs::from_command_response(output_type, response);
            println!("{}", result.unwrap_or(
                crate::types::TurtleOutputs::from_str("text", "Error formatting output".to_string()).unwrap(),
            ));

        }


        std::process::exit(status_code);
    }

    crate::config::load_aliases(&mut aliases, &config);

    crate::themes::apply_theme(&mut std::io::stdout(), &turtle_theme).ok();
    set_shell_vars();

    // Welcome message
    println!("Welcome to Turtle Shell! 🐢");

    let rl_config = Config::builder()
        .edit_mode(EditMode::Vi)
        .build();

    let mut rl = Editor::with_config(rl_config).unwrap();
    // Main REPL loop
    loop {

        let history = crate::history::load_history().unwrap_or_default();
        // we need to maintain a plain text history file for rustyline
        crate::history::export_history_for_rustyline(
            &format!("{}/.turtle_history.txt", dirs::home_dir().unwrap().display()),
        ).ok();
        rl.load_history(&format!("{}/.turtle_history.txt", dirs::home_dir().unwrap().display())).ok();
        let mut _history_index = history.len(); // start at the end of history

        let prompt = expand_prompt_macros(
            &prompt,
        );
        let readline = rl.readline(&prompt);

        // use readline to get user input
        let input = match readline {
            Ok(line) => {
                line
            }
            Err(rustyline::error::ReadlineError::Interrupted) => {
                println!("^C");
                continue;
            }
            Err(rustyline::error::ReadlineError::Eof) => {
                println!("^D");
                break;
            }
            Err(err) => {
                eprintln!("Error reading line: {}", err);
                continue;
            }
        };

        let input = input.trim();

        // skip empty user input
        if input.is_empty() {
            continue;
        }

        // expand env vars and tilde in input
        let input = expand_env_vars(input);
        let input = expand_tilde(&input);
        let input: String = expand_double_dot(&input);
        let input: String = expand_single_dot(&input);

        let tokens: Vec<crate::types::TurtleToken> = turtle_intepreter.tokenize(&input);
        let expression = turtle_intepreter.interpret();

        println!("Input Tokens: {:?}", tokens);
        println!("Expression: {:?}", expression);


        // split input into command and args by whitespace
        // TODO: replace with shlex to properly handle quoted args and remain POSIX compliant
        let mut parts = input.split_whitespace();
        let cmd = match parts.next() {
            Some(c) => c,
            None => continue,
        };

        // collect remaining parts as args vector, each arg also needs to have env vars and tilde expanded
        let args: Vec<String> = parts.map(|arg| {
            let arg = expand_env_vars(arg);
            expand_tilde(&arg);
            expand_double_dot(&arg);
            expand_single_dot(&arg)
        }).collect();


        // handle special commands for widgets
        // TODO: refactor into builtin commands
        if input.trim() == "%(history)" {
            let _ = crate::history::display_history_ui();
            continue;
        }

        if input.trim() == "%(clear_history)" {
            match crate::history::clear_history() {
                Ok(_) => println!("History cleared."),
                Err(e) => eprintln!("Error clearing history: {}", e),
            }
            continue;
        }

        if input.trim() == "%(file_browser)" {
            let _ = crate::widgets::display_file_browser_ui();
            continue;
        }

        if input.trim() == "%(text_editor)" {
            let _ = crate::widgets::display_text_editor_ui();
            continue;
        }

        if input.trim() == "%(terminal)" {
            let _ = crate::widgets::display_terminal_ui();
            continue;
        }


        // process builtin commands
        match cmd {
            "cd" => {
                let arg_refs: Vec<&str> = args.iter().map(|s| s.as_str()).collect();
                builtin::builtin_cd(&arg_refs);
                continue;
            }
            "exit" => {
                builtin::builtin_exit();
            }
            "history" => {
                builtin::builtin_history();
                continue;
            }
            "alias" => {
                let arg_refs: Vec<&str> = args.iter().map(|s| s.as_str()).collect();
                aliases = builtin::builtin_alias(&mut aliases, &arg_refs);
                continue;
            }
            "test" => {
                let arg_refs: Vec<&str> = args.iter().map(|s| s.as_str()).collect();
                let operation = arg_refs.get(0).unwrap_or(&"");
                let arg_refs = if operation.starts_with('-') {
                    arg_refs[1..].to_vec()
                } else {
                    arg_refs.clone()
                };
                let result = builtin::builtin_test(operation.to_string(), arg_refs);
                // TODO: we need to set the exit code of the last command here
                println!("{}", if result { "true" } else { "false" });
                continue;
            }
            _ => {}
        }

        // translate aliases to their commands
        let (cmd, args) = if let Some(alias_command) = aliases.get(cmd) {
            let mut alias_parts = alias_command.split_whitespace();
            let alias_cmd = alias_parts.next().unwrap_or(cmd);
            let mut alias_args: Vec<String> = alias_parts.map(|s| s.to_string()).collect();
            alias_args.extend(args);
            (alias_cmd, alias_args)
        } else {
            (cmd, args)
        };

        let id = Uuid::new_v4().to_string();
        let timestamp = now_unix();

        // Build the command request
        let command_request = CommandRequest {
            id: id.clone(),
            command: cmd.to_string(),
            args: args.iter().map(|s| s.to_string()).collect(),
            timestamp,
            event: "command_request".to_string(),
        };


        // Try to execute the command in PATH
        let status = Command::new(cmd)
            .args(&args)
            .stdin(Stdio::inherit())
            // .stdout(Stdio::inherit())
            // .stderr(Stdio::inherit())
            .output();

        // Build the command response
        let command_response = match &status {
            Ok(s) => {
                let stdout = String::from_utf8_lossy(&s.stdout).to_string();
                let stderr = String::from_utf8_lossy(&s.stderr).to_string();
                CommandResponse {
                    id: id.clone(),
                    status: "completed".to_string(),
                    code: 0,
                    output: stdout,
                    errors: stderr,
                    timestamp: now_unix(),
                    event: "command_response".to_string(),
                }
            }

            Err(e) => {
                CommandResponse {
                    id: id.clone(),
                    status: "failed".to_string(),
                    code: -1,
                    output: "".to_string(),
                    errors: e.to_string(),
                    timestamp: now_unix(),
                    event: "command_response".to_string(),
                }
            }
        };

        // Ensure output starts on a new line
        if !command_response.output.starts_with('\n') {
            println!();
        }

        println!("{}", command_response.output);

        // Log the command request and response to history
        log_history(&command_request).await;
        log_history(&command_response).await;

        if let Err(e) = status {
            eprintln!("turtle: command not found: {} ({})", cmd, e);
        }
    }
}