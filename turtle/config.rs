use std::env;
use crate::types::TurtleConfig;

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

pub fn set_shell_vars() {
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
