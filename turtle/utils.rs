use std::time::{SystemTime, UNIX_EPOCH};

pub fn now_unix() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs()
}

pub fn is_command_in_path(command: &str) -> bool {
    if let Ok(paths) = std::env::var("PATH") {
        for path in paths.split(std::path::MAIN_SEPARATOR) {
            let full_path = std::path::Path::new(path).join(command);
            if full_path.exists() && full_path.is_file() {
                return true;
            }
        }
    }
    false
}

pub fn translate_alias(aliases: &std::collections::HashMap<String, String>, input: &str) -> Option<String> {
    let parts: Vec<&str> = input.split_whitespace().collect();
    if let Some(alias_command) = aliases.get(parts[0]) {
        let mut command = alias_command.clone();
        if parts.len() > 1 {
            command.push(' ');
            command.push_str(&parts[1..].join(" "));
        }
        Some(command)
    } else {
        None
    }
}