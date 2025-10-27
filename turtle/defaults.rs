use serde::{Deserialize, Serialize};

// pub static DEFAULT_CONFIG_PATH: &str = "~/.turtlerc.yaml";
// pub static DEFAULT_HISTORY_PATH: &str = "~/.turtle_history.json";
pub static DEFAULT_PROMPT: &str = "<<🐢>> ";
pub static DEFAULT_HISTORY_SIZE: usize = 1000;
pub static DEFAULT_THEME: &str = "solarized_dark";
pub static DEFAULT_DEBUG: bool = false;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TurtleDefaults {
    pub config_path: String,
    pub history_path: String,
    pub prompt: String,
    pub history_size: usize,
    pub theme: String,
    pub debug: bool,
}

impl Default for TurtleDefaults {
    fn default() -> Self {
        let home = dirs::home_dir().unwrap_or_else(|| std::path::PathBuf::from("."));
        let config_path = home.join(".turtlerc.yaml");
        let history_path = home.join(".turtle_history.json");
        TurtleDefaults {
            config_path: config_path.to_string_lossy().to_string(),
            history_path: history_path.to_string_lossy().to_string(),
            prompt: DEFAULT_PROMPT.to_string(),
            history_size: DEFAULT_HISTORY_SIZE,
            theme: DEFAULT_THEME.to_string(),
            debug: DEFAULT_DEBUG,
        }
    }
}

pub fn get_defaults() -> TurtleDefaults {
    TurtleDefaults::default()
}
