mod config; // configuration loading and environment setup
mod input; // input handling (env var and tilde expansion)
mod history; // command history logging
mod utils; // utility functions
mod types; // shared structs/enums

mod builtin; // built-in commands

use clap::Parser;
use serde::{Serialize, Deserialize};
use serde_json::json;
use std::env;
use std::io::{self, Write};
use std::process::{Command, Stdio};
use std::fs::{OpenOptions};
use std::time::{SystemTime, UNIX_EPOCH};
use regex::Regex;
use uuid::Uuid;
use rustyline::config::{Builder, Config, EditMode};
use rustyline::{DefaultEditor as Editor, Result};
use rustyline::history::DefaultHistory;
use rustyline::Result as RustylineResult;

use crate::config::{load_config, set_shell_vars};
use crate::input::{expand_env_vars, expand_tilde};
use crate::history::{log_history};
use crate::utils::{now_unix};
use crate::types::{CommandRequest, CommandResponse, Args};


fn main() {
    let progArgs = Args::parse();

    set_shell_vars();
    load_config();
    let readline_config = Config::builder()
        .edit_mode(EditMode::Vi)
        .build();

    let mut rl = Editor::with_config(readline_config).unwrap();
    let username = whoami::username();
    let hostname = whoami::hostname();

    // main REPL loop
    /*
    main REPL loop
    - process user input
        - expand env vars and tilde
        - parse command and args
    - log command request
    - execute command
    - log command response
    - display output/errors
    */
    loop {
        let prompt = format!("{}@{}$ ", username, hostname);
        let readline = rl.readline(&prompt);
        // let progArgs = Args
        print!("{}", prompt);
        io::stdout().flush().unwrap();

        // let mut input = String::new();
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




        // if io::stdin().read_line(&mut input).is_err() {
        //     continue;
        // }

        let input = input.trim();
        if input.is_empty() {
            continue;
        }
        if input == "exit" {
            break;
        }


        let input = expand_env_vars(input);
        let input = expand_tilde(&input);


        let mut parts = input.split_whitespace();
        let cmd = match parts.next() {
            Some(c) => c,
            None => continue,
        };

        match cmd {
            "cd" => {
                let args: Vec<&str> = parts.collect();
                builtin::builtin_cd(&args);
                continue;
            }
            "exit" => {
                builtin::builtin_exit();
            }
            "history" => {
                builtin::builtin_history();
                continue;
            }
            _ => {}
        }
        let args: Vec<&str> = parts.collect();

        // each arg also needs to have env vars and tilde expanded
        let args: Vec<String> = args.iter()
            .map(|arg| {
                let arg = expand_env_vars(arg);
                expand_tilde(&arg)
            })
            .collect();

        let id = Uuid::new_v4().to_string();
        let timestamp = now_unix();

        let command_request = CommandRequest {
            id: id.clone(),
            command: cmd.to_string(),
            args: args.iter().map(|s| s.to_string()).collect(),
            timestamp,
            event: "command_request",
        };
        log_history(&command_request);

        // Try to execute the command in PATH
        let status = Command::new(cmd)
            .args(&args)
            .stdin(Stdio::inherit())
            .stdout(Stdio::inherit())
            .stderr(Stdio::inherit())
            .output();

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
                    event: "command_response",
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
                    event: "command_response",
                }
            }
        };

        println!("{}", command_response.output);
        log_history(&command_response);

        if let Err(e) = status {
            eprintln!("turtle: command not found: {} ({})", cmd, e);
        }
    }
}