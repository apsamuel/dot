use crate::types::TurtleConfig;
/// Functions for loading and managing Turtle shell configuration
use std::env;

/// Load Turtle shell configuration from ~/.turtle.yaml
pub fn load_config(debug: bool) -> Option<TurtleConfig> {
    if let Some(home) = dirs::home_dir() {
        let rc_path = home.join(".turtle.yaml");
        if rc_path.exists() {
            if debug {
                println!("Loading config from {:?}", rc_path);
            }

            if let Ok(contents) = std::fs::read_to_string(&rc_path) {
                if let Ok(config) = serde_yaml::from_str::<crate::types::TurtleConfig>(&contents) {
                    if debug {
                        println!("Loaded config from {:?}", rc_path);
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

                    return Some(config);
                } else {
                    eprintln!("Failed to parse config file");
                }
            }
        }
    }
    None
}

/// Set default shell environment variables
pub fn set_shell_vars() {
    // Set SHELL to the path of the running binary
    if let Ok(exe_path) = std::env::current_exe() {
        if let Some(path_str) = exe_path.to_str() {
            unsafe {
                env::set_var("SHELL", path_str);
            }
        }
    }

    // TODO: Set other default shell variables as needed
}

/// Load aliases from configuration into the provided aliases map
pub fn load_aliases(
    aliases: &mut std::collections::HashMap<String, String>,
    config: &Option<crate::types::TurtleConfig>,
) -> std::collections::HashMap<String, String> {
    let turtle_aliases = if let Some(cfg) = config {
        cfg.aliases.clone().unwrap_or_default()
    } else {
        std::collections::HashMap::new()
    };
    for (key, value) in turtle_aliases {
        aliases.insert(key, value);
    }

    aliases.clone()
}
