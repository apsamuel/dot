use std::time::{SystemTime, UNIX_EPOCH};

pub fn now_unix() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs()
}

pub fn _is_a_path(path: &str) -> bool {
    let p = std::path::Path::new(path);
    p.exists()
        && (p.is_file() || p.is_dir() || path.starts_with("./") || path.starts_with("../"))
}

pub fn _is_command_in_path(command: &str) -> bool {
    use is_executable::IsExecutable;
    // handle absolute and relative paths to commands first
    if command.starts_with("./") || command.starts_with('/') {
        let path = std::path::Path::new(command);
        return path.exists() && path.is_file() && path.is_executable();
    }

    // otherwise check in PATH directories
    if let Ok(paths) = std::env::var("PATH") {
        for path in std::env::split_paths(&paths) {
            let full_path = path.join(command);
            if full_path.exists() && full_path.is_file() && full_path.is_executable() {
                return true;
            }
        }
    }
    false
}

pub fn _translate_alias(
    aliases: &std::collections::HashMap<String, String>,
    input: &str,
) -> Option<String> {
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
