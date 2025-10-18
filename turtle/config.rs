
use std::env;

pub fn load_config() {
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
