
use serde::{Serialize, Deserialize};
use clap::Parser;
use crossterm::style::Color;

#[derive(Debug, Serialize, Deserialize)]
pub struct TurtleConfig {
    pub prompt: Option<String>,
    pub aliases: Option<std::collections::HashMap<String, String>>,
    pub history_size: Option<usize>,
    pub theme: Option<String>,
}

#[derive(Parser, Debug)]
#[command(name = "turtle", about = "A simple shell implemented in Rust")]
pub struct TurtleArgs {
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


// #[derive(Debug)]
pub struct TurtleTheme {
    pub foreground: Color,
    pub background: Color,
    pub text: Color,
    pub cursor: Color,
    pub selection: Color,
    // pub attributes: Vec<&'static str>,
}