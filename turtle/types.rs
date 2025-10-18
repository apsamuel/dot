
use serde::{Serialize, Deserialize};
use serde_json::json;
use clap::Parser;

#[derive(Parser, Debug)]
#[command(name = "turtle", about = "A simple shell implemented in Rust")]
pub struct Args {
    #[arg(short, long, help = "Enable verbose output")]
    pub verbose: bool,
}

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
    pub errors: String,
    pub timestamp: u64,
    pub event: &'static str,
}