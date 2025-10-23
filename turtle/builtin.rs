/// Built-in command implementations for the Turtle shell
///
/// This module provides functions for built-in commands such as `cd`, `exit`, `test`, `history`, and `alias`.

/// Change the current working directory
pub fn builtin_cd(args: &[&str]) {
    let home = std::env::var("HOME").unwrap();
    let dest = args.get(0).map(|s| *s).unwrap_or(home.as_str());
    if let Err(e) = std::env::set_current_dir(dest) {
        eprintln!("cd: {}: {}", dest, e);
    }
}

/// Exit the Turtle shell
pub fn builtin_exit() {
    std::process::exit(0);
}

/// Evaluate file and string tests
pub fn builtin_test(operation: String, args: Vec<&str>) -> bool {
    match operation.as_str() {
        "-e" | "--exists" => {
            if let Some(path) = args.get(0) {
                std::path::Path::new(path).exists()
            } else {
                false
            }
        }
        "-f" | "--is-file" => {
            if let Some(path) = args.get(0) {
                std::path::Path::new(path).is_file()
            } else {
                false
            }
        }
        "-d" | "--is-dir" => {
            if let Some(path) = args.get(0) {
                std::path::Path::new(path).is_dir()
            } else {
                false
            }
        }
        "-L" | "--is-symlink" => {
            if let Some(path) = args.get(0) {
                if let Ok(metadata) = std::fs::symlink_metadata(path) {
                    metadata.file_type().is_symlink()
                } else {
                    false
                }
            } else {
                false
            }
        }
        "-G" | "--is-git-repo" => {
            if let Some(path) = args.get(0) {
                let git_path = std::path::Path::new(path).join(".git");
                git_path.exists() && git_path.is_dir()
            } else {
                false
            }
        }
        "-g" | "--is-setgid" => {
            if let Some(path) = args.get(0) {
                if let Ok(metadata) = std::fs::metadata(path) {
                    #[cfg(unix)]
                    {
                        use std::os::unix::fs::PermissionsExt;
                        return (metadata.permissions().mode() & 0o2000) != 0;
                    }
                    // Windows and other platforms do not support setgid
                    #[cfg(not(unix))]
                    {
                        println!("-g/--is-setgid is not supported on this platform");
                        return false;
                    }
                }
                false
            } else {
                false
            }
        }
        "-r" | "--is-readable" => {
            if let Some(path) = args.get(0) {
                if let Ok(metadata) = std::fs::metadata(path) {
                    #[cfg(unix)]
                    {
                        use std::os::unix::fs::PermissionsExt;
                        let mode = metadata.permissions().mode();
                        return (mode & 0o400) != 0;
                    }
                    // Windows and other platforms do not support Unix-style permissions
                    #[cfg(not(unix))]
                    {
                        println!("-r/--is-readable is not supported on this platform");
                        return false;
                    }
                }
                false
            } else {
                false
            }
        }
        "-b" | "--is-block" => {
            if let Some(path) = args.get(0) {
                if let Ok(metadata) = std::fs::metadata(path) {
                    #[cfg(unix)]
                    {
                        use std::os::unix::fs::FileTypeExt;
                        return metadata.file_type().is_block_device();
                    }
                    // Windows and other platforms do not support block devices
                    #[cfg(not(unix))]
                    {
                        println!("-b/--is-block is not supported on this platform");
                        return false;
                    }
                }
                false
            } else {
                false
            }
        }
        "-p" | "--is-pipe" => {
            if let Some(path) = args.get(0) {
                if let Ok(metadata) = std::fs::metadata(path) {
                    #[cfg(unix)]
                    {
                        use std::os::unix::fs::FileTypeExt;
                        return metadata.file_type().is_fifo();
                    }
                    // Windows and other platforms do not support pipes in the same way
                    #[cfg(not(unix))]
                    {
                        println!("-p/--is-pipe is not supported on this platform");
                        return false;
                    }
                }
                false
            } else {
                false
            }
        }
        "-k" | "--is-sticky" => {
            if let Some(path) = args.get(0) {
                if let Ok(metadata) = std::fs::metadata(path) {
                    #[cfg(unix)]
                    {
                        use std::os::unix::fs::PermissionsExt;
                        return (metadata.permissions().mode() & 0o1000) != 0;
                    }
                    // Windows and other platforms do not support sticky bit
                    #[cfg(not(unix))]
                    {
                        println!("-k/--is-sticky is not supported on this platform");
                        return false;
                    }
                }
                false
            } else {
                false
            }
        }
        "-s" | "--file-not-zero" => {
            if let Some(path) = args.get(0) {
                if let Ok(metadata) = std::fs::metadata(path) {
                    return metadata.len() != 0;
                }
            }
            false
        }

        "-n" | "--string-not-zero" => {
            if let Some(s) = args.get(0) {
                return s.len() != 0;
            }
            false
        }
        _ => false,
    }
}

/// Display command history
pub fn builtin_history() {
    match crate::history::load_history() {
        Ok(entries) => {
            for (i, entry) in entries.iter().enumerate() {
                println!("{}: {}", i + 1, entry);
            }
        }
        Err(e) => eprintln!("Error loading history: {}", e),
    }
}

/// Manage command aliases
pub fn builtin_alias(
    aliases: &mut std::collections::HashMap<String, String>,
    args: &[&str],
) -> std::collections::HashMap<String, String> {
    if args.is_empty() {
        for (name, command) in aliases.iter() {
            println!("alias {}='{}'", name, command);
        }
        return aliases.clone();
    }

    if args.len() == 1 {
        if args.contains(&"=") {
            let parts: Vec<&str> = args[0].splitn(2, '=').collect();
            if parts.len() == 2 {
                let name = parts[0];
                let command = parts[1].trim_matches('"');
                aliases.insert(name.to_string(), command.to_string());
                return aliases.clone();
            }
        }
    }

    if args.len() == 2 {
        let name = args[0];
        let command = args[1].trim_matches('"');
        aliases.insert(name.to_string(), command.to_string());
        return aliases.clone();
    }

    println!("invalid alias format");
    aliases.clone()
}
