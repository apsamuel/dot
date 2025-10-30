use crate::types::Config;
/// Functions for loading and managing Turtle shell configuration
use std::env;

/// Load Turtle shell configuration from ~/.turtle.yaml
pub fn load_config(debug: bool) -> Option<Config> {
    use std::fs;
    let path = dirs::home_dir()?.join(".turtle.yaml");
    let content = fs::read_to_string(&path).ok()?;
    match serde_yaml::from_str::<Config>(&content) {
        Ok(config) => {
            if debug {
                println!("loaded config from {:?}", path);
            }
            if let Some(prompt) = config.prompt.as_ref() {
                unsafe {
                    env::set_var("TURTLE_PROMPT", prompt);
                }
            }

            if let Some(aliases) = config.aliases.as_ref() {
                for (k, v) in aliases {
                    unsafe {
                        env::set_var(format!("TURTLE_ALIAS_{}", k), v);
                    }
                }
            }

            Some(config)
        }
        Err(e) => {
            eprintln!("failed to parse config file: {}", e);
            None
        }
    }
}

/// Load Turtleshell configuratin from a specified path
pub fn load_config_from_path(path: &str) -> Option<Config> {
    use std::fs;

    // Expand ~ to home directory
    let expanded_path = if path.starts_with("~") {
        if let Some(home) = dirs::home_dir() {
            let without_tilde = path.trim_start_matches("~");
            home.join(without_tilde).to_string_lossy().to_string()
        } else {
            path.to_string()
        }
    } else {
        path.to_string()
    };
    let content = fs::read_to_string(&expanded_path).ok()?;
    match serde_yaml::from_str::<Config>(&content) {
        Ok(config) => Some(config),
        Err(e) => {
            eprintln!("❌ failed to parse config file: {}", e);
            None
        }
    }
}
