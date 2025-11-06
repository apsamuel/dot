use std::time::{SystemTime, UNIX_EPOCH};

pub fn now_unix() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs()
}

#[test]
fn test_now_unix() {
    let unix_time = now_unix();
    assert!(unix_time > 0);
}

/// Get the current instant
pub fn now() -> std::time::Instant {
    std::time::Instant::now()
}

#[test]
fn test_this_instant() {
    let instant = now();
    assert!(instant.elapsed().as_secs() >= 0);
}

/// Get the elapsed time
pub fn elapsed_millis(start: std::time::Instant) -> u128 {
    start.elapsed().as_millis()
}

#[test]
fn test_elapsed_millis() {
    let start = now();
    std::thread::sleep(std::time::Duration::from_millis(100));
    let elapsed = elapsed_millis(start);
    assert!(elapsed >= 100);
}

/// Expands path modifiers (~, etc.) in a given path string
pub fn expand_path(path: &str) -> String {
    if path.starts_with("~/") {
        if let Some(home) = dirs::home_dir() {
            let without_tilde = &path[2..]; // Remove "~/"
            return home.join(without_tilde).to_string_lossy().to_string();
        }
    } else if path == "~" {
        if let Some(home) = dirs::home_dir() {
            return home.to_string_lossy().to_string();
        }
    }
    path.to_string()
}

#[test]
fn test_expand_path() {
    let home = dirs::home_dir().unwrap().to_string_lossy().to_string();
    assert_eq!(expand_path("~/documents"), format!("{}/documents", home));
    assert_eq!(expand_path("~"), home);
    assert_eq!(expand_path("/usr/bin"), "/usr/bin".to_string());
    assert_eq!(expand_path("relative/path"), "relative/path".to_string());
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

#[test]
fn test_is_path() {
    assert!(is_path("/etc/passwd"));
    assert!(is_path("/usr/bin"));
    assert!(is_path("./main.rs")); // assuming this file exists
    assert!(!is_path("/non/existent/path"));
    assert!(!is_path("alias")); // assuming 'alias' is not a file or directory
    //confirm
}

/// Check if the given command exists in PATH or is an executable file
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

#[test]
fn test_is_command() {
    assert!(is_command("ls")); // assuming 'ls' is in PATH
    assert!(!is_command("nonexistentcommand"));
}

/// Build a user environment details map
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

#[test]
fn test_build_user_environment() {
    let env = build_user_environment();
    assert!(env.contains_key("USER"));
    assert!(env.contains_key("HOME"));
    assert_ne!(env.get("USER").unwrap(), "testuser");
    assert_ne!(env.get("HOME").unwrap(), "/home/testuser");
}
