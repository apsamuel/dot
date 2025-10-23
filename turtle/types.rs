use clap::Parser;
use crossterm::style::Color;
use serde::{Deserialize, Serialize};

/// Represents YAML configuration for the Turtle shell
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TurtleConfig {
    pub debug: bool,
    pub prompt: Option<String>,
    pub aliases: Option<std::collections::HashMap<String, String>>,
    pub history_size: Option<usize>,
    pub theme: Option<String>,
}

/// Represents command line arguments available to the Turtle shell
#[derive(Parser, Clone, Debug)]
#[command(name = "turtle", about = "A simple shell implemented in Rust")]
pub struct TurtleArgs {
    #[arg(short, long, help = "Enable debug output")]
    pub debug: bool,
    #[arg(short, long, help = "Returns turtle version")]
    pub version: bool,
    #[arg(short, long, help = "Run in non-interactive mode with the provided command")]
    pub command: Option<String>,
}

/// Commands are sent as CommandRequest structs
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct CommandRequest {
    pub id: String,
    pub command: String,
    pub args: Vec<String>,
    pub timestamp: u64,
    pub event: String,
}

/// Responses are sent as CommandResponse structs
#[derive(Serialize, Deserialize, Debug, Clone)]
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
#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "event")]
pub enum HistoryEvent {
    #[serde(rename = "command_request")]
    CommandRequest(CommandRequest),
    #[serde(rename = "command_response")]
    CommandResponse(CommandResponse),
}

#[derive(Debug, Clone)]
#[allow(dead_code)] //for now until we use all variants
pub struct TurtleTheme {
    pub foreground: Color,
    pub background: Color,
    pub text: Color,
    pub cursor: Color,
    pub selection: Color,
    // pub attributes: Vec<&'static str>,
}

#[derive(Debug, Clone, PartialEq)]
// #[allow(dead_code)] //for now until we use all variants
pub enum TurtleToken {
    Arrow,              // process arrow '->'
    Boolean(bool),      // True or False
    BraceClose,         // }/
    BraceOpen,          // {/
    BracketClose,       // ]/
    BracketOpen,        // [/
    Builtin(String),    // built-in function names
    Colon,              // :
    Comma,              // ,
    Eof,                // end of file/input
    Identifier(String), // variable names
    Keyword(String),    // if, else, while, for, func, return, break, continue
    Number(f64),        // numeric literals
    Operator(String),   // +, -, *, /, %, ==, !=, <, >, <=, >=, &&, ||, !
    ParenClose,         // )/
    ParenOpen,          // (/
    String(String),     // string literals
    Comment(String),
    Dot,       // .
    Semicolon, // ;
}

#[derive(Debug, Clone)]
#[allow(dead_code)] //for now until we use all variants
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
    UnaryExpression {
        op: String,
        expr: Box<TurtleExpression>,
    },
    // Binary Operation - ex: 1 + 2, x - 3
    BinaryExpression {
        left: Box<TurtleExpression>,
        op: String,
        right: Box<TurtleExpression>,
    },
    // If Control Flow - ex: if cond { ... } else { ... } or if cond { ... }
    IfCondition {
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
        body: Box<TurtleExpression>,
    },
    RegularExpression {
        pattern: String,
        flags: Option<String>,
    },
    InfiniteLoop {
        body: Box<TurtleExpression>,
    },
    FuncDef {
        name: String,
        params: Vec<String>,
        body: Box<TurtleExpression>,
    },
    CodeBlock {
        expressions: Vec<TurtleExpression>,
    },
    FuncCall {
        func: String,
        args: Vec<TurtleExpression>,
    },
    MemberAccess {
        object: Box<TurtleExpression>,
        property: String,
    },
    Builtin {
        name: String,
        args: Vec<TurtleExpression>,
    },
    Executable {
        name: String,
        args: Vec<TurtleExpression>,
    },
    Path {
        segments: Vec<String>,
    },
}
