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
