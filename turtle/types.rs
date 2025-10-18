
use serde::{Serialize, Deserialize};
use serde_json::json;


#[derive(Serialize, Deserialize, Debug)]
pub struct CommandRequest {
    pub id: String,
    pub command: String,
    pub args: Vec<String>,
    pub timestamp: u64,
    pub event: &'static str,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct CommandResponse {
    pub id: String,
    pub status: String,
    pub code: i32,
    pub output: String,
    pub timestamp: u64,
    pub event: &'static str,
}