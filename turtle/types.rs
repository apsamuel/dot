
use serde::{Serialize, Deserialize};
use clap::Parser;
use crossterm::style::Color;

/// Configuration for the Turtle shell
#[derive(Debug, Serialize, Deserialize)]
pub struct TurtleConfig {
    pub prompt: Option<String>,
    pub aliases: Option<std::collections::HashMap<String, String>>,
    pub history_size: Option<usize>,
    pub theme: Option<String>,
}

//// Command line arguments available to the Turtle shell
#[derive(Parser, Debug)]
#[command(name = "turtle", about = "A simple shell implemented in Rust")]
pub struct TurtleArgs {
    #[arg(short, long, help = "Enable verbose output")]
    pub verbose: bool,
    #[arg(long, help  = "Returns turtle version")]
    pub version: bool,
}

/// Commands are sent as CommandRequest structs
#[derive(Serialize, Deserialize, Debug)]
pub struct CommandRequest {
    pub id: String,
    pub command: String,
    pub args: Vec<String>,
    pub timestamp: u64,
    pub event: String,
}

/// Responses are sent as CommandResponse structs
#[derive(Serialize, Deserialize, Debug)]
pub struct CommandResponse {
    pub id: String,
    pub status: String,
    pub code: i32,
    pub output: String,
    pub errors: String,
    pub timestamp: u64,
    pub event: String,
}

/// Encapsulate both CommandRequest and CommandResponse
#[derive(Serialize, Deserialize, Debug)]
#[serde(tag = "event")]
pub enum HistoryEvent {
    #[serde(rename = "command_request")]
    CommandRequest(CommandRequest),
    #[serde(rename = "command_response")]
    CommandResponse(CommandResponse),
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

#[derive(Debug, Clone, PartialEq)]
pub enum TurtleToken {
    Identifier(String),
    Operator(String),
    Number(f64),
    String(String),
    // Command{
    //     name: String,
    //     args: Vec<TurtleToken>
    // },
    Boolean(bool),
    BracketOpen,
    BracketClose,
    BraceOpen,
    BraceClose,
    ParenOpen,
    ParenClose,
    Colon,
    Arrow,
    Keyword(String),
    Builtin(String),
    Comma,
    Eof,
    // Whitespace,
    // Comment(String),
    // Dot,
    // CommandS
}

#[derive(Debug, Clone)]
// #[allow(dead_code)]
pub enum TurtleExpression {
    // Literal values
    Number(f64),
    String(String),
    Boolean(bool),
    // Composite values
    Array(Vec<TurtleExpression>),
    Object(Vec<(String, TurtleExpression)>),
    // Variables and operations
    Identifier(String),
    // Unary Operation - ex: -5, !true
    UnaryOp {
        op: String,
        expr: Box<TurtleExpression>
    },
    // Binary Operation - ex: 1 + 2, x - 3
    BinaryOp {
        left: Box<TurtleExpression>,
        op: String,
        right: Box<TurtleExpression>,
    },
    // If Control Flow - ex: if cond { ... } else { ... } or if cond { ... }
    IfCond {
        condition: Box<TurtleExpression>,
        then_branch: Box<TurtleExpression>,
        else_branch: Option<Box<TurtleExpression>>,
    },
    // While Loop Control Flow - ex: while cond { ... }
    WhileLoop {
        condition: Box<TurtleExpression>,
        body: Box<TurtleExpression>,
    },
    ForLoop {
        iterator: String,
        iterable: Box<TurtleExpression>,
        body: Box<TurtleExpression>
    },
    Regex {
        pattern: String,
        flags: Option<String>
    },
    InfiniteLoop {
        body: Box<TurtleExpression>
    },
    FuncDef {
        name: String,
        params: Vec<String>,
        body: Box<TurtleExpression>,
    },
    CodeBlock {
        expressions: Vec<TurtleExpression>
    },
    FuncCall {
        func: String,
        args: Vec<TurtleExpression>
    },
    CommandCall {
        name: String,
        args: Vec<TurtleExpression>
    }
}
