use std::fs::{OpenOptions};
use std::io::{self, Write};
use serde::{Serialize, Deserialize};
use serde_json::json;


pub fn log_history<T: Serialize>(entry: &T) {
    let home = dirs::home_dir().unwrap();
    let history_path = home.join(".turtle_history.log");
    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(history_path)
        .unwrap();
    let json = serde_json::to_string(entry).unwrap();
    writeln!(file, "{}", json).unwrap();
}

// load history from .turtle_history.log
pub fn load_history() -> io::Result<Vec<serde_json::Value>> {
    let home = dirs::home_dir().unwrap();
    let history_path = home.join(".turtle_history.log");
    let content = std::fs::read_to_string(history_path)?;
    let mut history = Vec::new();
    for line in content.lines() {
        if let Ok(entry) = serde_json::from_str::<serde_json::Value>(line) {
            history.push(entry);
        }
    }
    Ok(history)
}