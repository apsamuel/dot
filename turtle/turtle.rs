use serde::{Serialize, Deserialize};
use serde_json::json;
use std::env;
use std::io::{self, Write};
use std::process::{Command, Stdio};
use std::fs::{OpenOptions};
use std::time::{SystemTime, UNIX_EPOCH};
use regex::Regex;
use uuid::Uuid;

#[derive(Serialize, Deserialize, Debug)]
struct CommandRequest {
    id: String,
    command: String,
    args: Vec<String>,
    timestamp: u64,
    event: &'static str,
}

#[derive(Serialize, Deserialize, Debug)]
struct CommandResponse {
    id: String,
    status: String,
    return_code: i32,
    output: String,
    timestamp: u64,
    event: &'static str,
}

fn log_history<T: Serialize>(entry: &T) {
  let home = dirs::home_dir().unwrap();
  let history_path = home.join(".turtle_history.log");
  let mut file = OpenOptions::new()
      .create(true)
      .append(true)
      .open(history_path)
      .unwrap();
  let json = serde_json::to_string(entry).unwrap();
  writeln!(file, "{}", json).unwrap();
}

fn now_unix() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs()
}

fn load_config() {
    if let Some(home) = dirs::home_dir() {
        let rc_path = home.join(".turtlerc");
        if rc_path.exists() {
            if let Ok(lines) = std::fs::read_to_string(&rc_path) {
                for line in lines.lines() {
                    if let Some((k, v)) = line.split_once('=') {
                        unsafe {
                          env::set_var(k.trim(), v.trim());
                        }
                        // env::set_var(k.trim(), v.trim());
                    }
                }
            }
        }
    }
}

fn set_shell_vars() {
    // Set SHELL to the path of the running binary
    if let Ok(exe_path) = std::env::current_exe() {
        if let Some(path_str) = exe_path.to_str() {
          unsafe {
            env::set_var("SHELL", path_str);
          }

        }
    }
    // You can set other default variables here as needed
}

fn expand_env_vars(input: &str) -> String {
    let re = Regex::new(r"\$([A-Za-z_][A-Za-z0-9_]*)").unwrap();
    re.replace_all(input, |caps: &regex::Captures| {
        let var_name = &caps[1];
        env::var(var_name).unwrap_or_default()
    })
    .to_string()
}

fn expand_tilde(input: &str) -> String {
    if input.starts_with("~") {
        if let Some(home) = dirs::home_dir() {
            return input.replacen("~", home.to_str().unwrap(), 1);
        }
    }
    input.to_string()
}

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

        // let id = Uuid::new_v4().
        let timestamp = now_unix();

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