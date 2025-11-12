use regex::Regex;
use std::env;

#[allow(dead_code)]
pub fn expand_env_vars(input: &str) -> String {
    let re = Regex::new(r"\$([A-Za-z_][A-Za-z0-9_]*)").unwrap();
    re.replace_all(input, |caps: &regex::Captures| {
        let var_name = &caps[1];
        env::var(var_name).unwrap_or_default()
    })
    .to_string()
}

#[allow(dead_code)]
pub fn expand_tilde(input: &str) -> String {
    if input.starts_with("~") {
        if let Some(home) = dirs::home_dir() {
            return input.replacen("~", home.to_str().unwrap(), 1);
        }
    }
    input.to_string()
}

#[allow(dead_code)]
pub fn expand_single_dot(input: &str) -> String {
    if input.starts_with("./") || input == "." {
        if let Ok(current_dir) = env::current_dir() {
            return input.replacen(".", current_dir.to_str().unwrap(), 1);
        }
    }
    input.to_string()
}

#[allow(dead_code)]
pub fn expand_double_dot(input: &str) -> String {
    if input.starts_with("../") || input == ".." {
        if let Ok(current_dir) = env::current_dir() {
            if let Some(parent) = current_dir.parent() {
                return input.replacen("..", parent.to_str().unwrap(), 1);
            }
        }
    }
    input.to_string()
}
