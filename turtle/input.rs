use regex::Regex;
use std::env;


pub fn expand_env_vars(input: &str) -> String {
    let re = Regex::new(r"\$([A-Za-z_][A-Za-z0-9_]*)").unwrap();
    re.replace_all(input, |caps: &regex::Captures| {
        let var_name = &caps[1];
        env::var(var_name).unwrap_or_default()
    })

    .to_string()
}

pub fn expand_tilde(input: &str) -> String {
    if input.starts_with("~") {
        if let Some(home) = dirs::home_dir() {
            return input.replacen("~", home.to_str().unwrap(), 1);
        }
    }
    input.to_string()
}
