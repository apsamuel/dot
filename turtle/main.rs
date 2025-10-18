mod config; // configuration loading and environment setup
mod input; // input handling (env var and tilde expansion)
mod history; // command history logging
mod utils; // utility functions (e.g., timestamp)
mod types; // shared structs/enums (CommandRequest, CommandResponse)

use serde::{Serialize, Deserialize};
use serde_json::json;
use std::env;
use std::io::{self, Write};
use std::process::{Command, Stdio};
use std::fs::{OpenOptions};
use std::time::{SystemTime, UNIX_EPOCH};
use regex::Regex;
use uuid::Uuid;
use crate::config::{load_config, set_shell_vars};
use crate::input::{expand_env_vars, expand_tilde};
use crate::history::{log_history};
use crate::utils::{now_unix};
use crate::types::{CommandRequest, CommandResponse};

fn main() {
    set_shell_vars();
    load_config();
    let username = whoami::username();
    let hostname = whoami::hostname();

    loop {
        print!("{}@{}$ ", username, hostname);
        io::stdout().flush().unwrap();

        let mut input = String::new();
        if io::stdin().read_line(&mut input).is_err() {
            continue;
        }
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
        let args: Vec<&str> = parts.collect();

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
            .status();

        if let Err(e) = status {
            eprintln!("turtle: command not found: {} ({})", cmd, e);
        }
    }
}