use std::time::{SystemTime, UNIX_EPOCH};

pub fn now_unix() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs()
}

/// Get the current instant
pub fn this_instant() -> std::time::Instant {
    std::time::Instant::now()
}

/// Check if the given path exists and is a file or directory
pub fn is_path(path: &str) -> bool {
    let p = std::path::Path::new(path);
    p.exists()
        && (p.is_file()
            || p.is_dir()
            || path.starts_with("./")
            || path.starts_with("../")
            || path.starts_with('/'))
}

/// Check if the given command exists in PATH or as an absolute/relative path
pub fn is_command(command: &str) -> bool {
    use is_executable::IsExecutable;
    // handle absolute and relative paths to commands first
    if command.starts_with("./") || command.starts_with('/') {
        let path = std::path::Path::new(command);
        return path.exists() && path.is_file() && path.is_executable() && !path.is_dir();
    }

    // otherwise check in PATH directories
    if let Ok(paths) = std::env::var("PATH") {
        for path in std::env::split_paths(&paths) {
            let full_path = path.join(command);
            if full_path.exists()
                && full_path.is_file()
                && full_path.is_executable()
                && !full_path.is_dir()
            {
                return true;
            }
        }
    }
    false
}

pub fn translate_alias(
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

pub fn build_user_environment() -> std::collections::HashMap<String, String> {
    let mut details = std::collections::HashMap::new();
    if let Some(username) = users::get_current_username() {
        details.insert("USER".to_string(), username.to_string_lossy().to_string());
    }

    if let Some(home_dir) = dirs::home_dir() {
        details.insert("HOME".to_string(), home_dir.to_string_lossy().to_string());
    }
    return details;
}
