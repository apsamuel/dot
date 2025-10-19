mod config; // configuration loading and environment setup
mod input; // input handling (env var and tilde expansion)
mod history; // command history logging
mod utils; // utility functions
mod types; // shared structs/enums

mod builtin; // built-in commands

mod prompt; // prompt handling

use clap::Parser;
use std::process::{Command, Stdio};
use uuid::Uuid;
use rustyline::config::{Config, EditMode};
use rustyline::{DefaultEditor as Editor, Result};

use crate::config::{load_config, set_shell_vars};
use crate::input::{expand_env_vars, expand_tilde};
use crate::history::{log_history};
use crate::utils::{now_unix};
use crate::types::{CommandRequest, CommandResponse, TurtleArgs };
use crate::prompt::{expand_prompt_macros};
use crossterm::event::{self, Event, KeyCode};


fn main() {
    let prog_args = TurtleArgs::parse();

    set_shell_vars();
    let config = load_config(
        prog_args.verbose
    );
    // println!("Current config: {:?}", config);
    println!("Welcome to Turtle Shell! 🐢");


    let readline_config = Config::builder()
        .edit_mode(EditMode::Vi)
        .build();



    let mut rl = Editor::with_config(readline_config).unwrap();

    loop {
        let history = crate::history::load_history().unwrap_or_default();


        // we need to maintain a plain text history file for rustyline
        crate::history::export_history_for_rustyline(
            &format!("{}/.turtle_history.json", dirs::home_dir().unwrap().display()),
            &format!("{}/.turtle_history.txt", dirs::home_dir().unwrap().display()),
        ).ok();
        rl.load_history(&format!("{}/.turtle_history.txt", dirs::home_dir().unwrap().display())).ok();
        let mut history_index = history.len(); // start at the end of history

        let prompt = expand_prompt_macros(
            &std::env::var("TURTLE_PROMPT").unwrap_or_else(|_| "turtle> ".to_string())
        );
        let readline = rl.readline(&prompt);

        // use readline to get user input
        let input = match readline {
            Ok(line) => {
                // rl.add_history_entry(line.as_str()).unwrap_or(());
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

        // split input into command and args
        let mut parts = input.split_whitespace();
        let cmd = match parts.next() {
            Some(c) => c,
            None => continue,
        };

        // collect remaining parts as args vector, each arg also needs to have env vars and tilde expanded
        let args: Vec<String> = parts.map(|arg| {
            let arg = expand_env_vars(arg);
            expand_tilde(&arg)
        }).collect();

        if input.trim() == "%(history)" {
            let _ = crate::history::display_history_ui();
            continue;
        }

        // process built-in commands
        match cmd {
            "cd" => {
                // let args: Vec<&str> = parts.collect();
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
            _ => {}
        }


        let id = Uuid::new_v4().to_string();
        let timestamp = now_unix();

        // Build the command request
        let command_request = CommandRequest {
            id: id.clone(),
            command: cmd.to_string(),
            args: args.iter().map(|s| s.to_string()).collect(),
            timestamp,
            event: "command_request",
        };


        // Try to execute the command in PATH
        let status = Command::new(cmd)
            .args(&args)
            .stdin(Stdio::inherit())
            .stdout(Stdio::inherit())
            .stderr(Stdio::inherit())
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

        // Ensure output starts on a new line
        if !command_response.output.starts_with('\n') {
            println!();
        }

        println!("{}", command_response.output);

        // Log the command request and response to history
        log_history(&command_request);
        log_history(&command_response);

        if let Err(e) = status {
            eprintln!("turtle: command not found: {} ({})", cmd, e);
        }
    }
}