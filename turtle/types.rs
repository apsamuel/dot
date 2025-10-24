use clap::Parser;
use crossterm::style::Color;
use serde::{Deserialize, Serialize};
use std::fmt;

/// turtle shell configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TurtleConfig {
    pub debug: bool,
    pub prompt: Option<String>,
    pub aliases: Option<std::collections::HashMap<String, String>>,
    pub history_size: Option<usize>,
    pub theme: Option<String>,
}

/// turtle shell command line arguments
#[derive(Parser, Clone, Debug, Serialize, Deserialize)]
#[command(name = "turtle", about = "A simple shell implemented in Rust")]
pub struct TurtleArgs {
    /// enable debug output
    #[arg(short, long, help = "Enable debug output")]
    pub debug: bool,
    #[arg(short, long, help = "Returns turtle version")]
    /// show version information
    pub version: bool,
    #[arg(
        short,
        long,
        help = "Run in non-interactive mode with the provided command"
    )]
    /// command to execute in non-interactive mode
    pub command: Option<String>,
    #[arg(
        short,
        long,
        help = "format output: table, json, yaml, text, ast",
        default_value = "table"
    )]
    /// output format
    pub format: Option<String>,
}

#[derive(Debug, Clone)]
// #[serde(default)]
#[allow(dead_code)] //for now until we use all variants
pub struct TurtleTheme {
    pub foreground: Color,
    pub background: Color,
    pub text: Color,
    pub cursor: Color,
    pub selection: Color,
    // pub attributes: Vec<&'static str>,
}

/// CSV compatible output
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct TurtleOutputCsv {
    pub headers: Vec<String>,
    pub data: Vec<Vec<String>>,
}

/// YAML compatible output
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct TurtleOutputYaml {
    pub data: serde_yaml::Value,
}

/// JSON compatible output
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct TurtleOutputJson {
    pub data: serde_json::Value,
}

/// Plain text output
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct TurtleOutputText {
    pub data: String,
}

/// AST output
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct TurtleOutputAst {
    pub data: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub enum TurtleOutputs {
    Table(TurtleOutputCsv),
    Json(TurtleOutputJson),
    Yaml(TurtleOutputYaml),
    Text(TurtleOutputText),
    Ast(TurtleOutputAst),
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "event")]
pub enum _TurleOutputResults {
    #[serde(rename = "command_response")]
    CommandResponse(CommandResponse),
    #[serde(rename = "turtle_expression")]
    TurtleExpression(TurtleExpression),
}

impl fmt::Display for TurtleOutputs {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            TurtleOutputs::Table(table) => {
                let mut output = String::new();
                output.push_str(&table.headers.join("\t"));
                output.push('\n');
                for row in &table.data {
                    output.push_str(&row.join("\t"));
                    output.push('\n');
                }
                write!(f, "{}", output)
            }
            TurtleOutputs::Json(json) => {
                let json_string =
                    serde_json::to_string_pretty(&json.data).map_err(|_| fmt::Error)?;
                write!(f, "{}", json_string)
            }
            TurtleOutputs::Yaml(yaml) => {
                let yaml_string = serde_yaml::to_string(&yaml.data).map_err(|_| fmt::Error)?;
                write!(f, "{}", yaml_string)
            }
            TurtleOutputs::Text(text) => {
                write!(f, "{}", text.data)
            }
            TurtleOutputs::Ast(ast) => {
                write!(f, "{}", ast.data)
            }
        }
    }
}

impl TurtleOutputs {
    pub fn from_command_response(option: &str, response: CommandResponse) -> Option<Self> {
        match option {
            "table" => {
                // parse CSV data
                let mut rdr = csv::Reader::from_reader(response.output.as_bytes());
                let headers = rdr
                    .headers()
                    .unwrap()
                    .iter()
                    .map(|s| s.to_string())
                    .collect();
                let mut rows = Vec::new();
                for result in rdr.records() {
                    let record = result.unwrap();
                    let row = record.iter().map(|s| s.to_string()).collect();
                    rows.push(row);
                }
                Some(TurtleOutputs::Table(TurtleOutputCsv {
                    headers,
                    data: rows,
                }))
            }
            "json" => {
                // println!("Parsing JSON data...");
                // println!("Option: {}", option);
                // println!("Data: {:?}", response);
                // use serde to serialize the response object to json
                let json_data = serde_json::to_string(&response).ok()?;
                let json_data: serde_json::Value = serde_json::from_str(&json_data).ok()?;
                Some(TurtleOutputs::Json(TurtleOutputJson { data: json_data }))
            }
            "yaml" => {
                let yaml_data = serde_yaml::to_string(&response).ok()?;
                let yaml_data: serde_yaml::Value = serde_yaml::from_str(&yaml_data).ok()?;
                Some(TurtleOutputs::Yaml(TurtleOutputYaml { data: yaml_data }))
            }
            "text" => Some(TurtleOutputs::Text(TurtleOutputText {
                data: response.output,
            })),
            "ast" => Some(TurtleOutputs::Ast(TurtleOutputAst {
                data: response.output,
            })),
            _ => None,
        }
    }

    pub fn from_turtle_expression(expression: TurtleExpression) -> Option<Self> {
        match expression {
            TurtleExpression::String(s) => Some(TurtleOutputs::Text(TurtleOutputText { data: s })),
            TurtleExpression::Number(n) => Some(TurtleOutputs::Text(TurtleOutputText {
                data: n.to_string(),
            })),
            TurtleExpression::Boolean(b) => Some(TurtleOutputs::Text(TurtleOutputText {
                data: b.to_string(),
            })),
            _ => None,
        }
    }

    pub fn from_str(option: &str, data: String) -> Option<Self> {
        match option {
            "table" => {
                // parse CSV data
                let mut rdr = csv::Reader::from_reader(data.as_bytes());
                let headers = rdr
                    .headers()
                    .unwrap()
                    .iter()
                    .map(|s| s.to_string())
                    .collect();
                let mut rows = Vec::new();
                for result in rdr.records() {
                    let record = result.unwrap();
                    let row = record.iter().map(|s| s.to_string()).collect();
                    rows.push(row);
                }
                Some(TurtleOutputs::Table(TurtleOutputCsv {
                    headers,
                    data: rows,
                }))
            }
            "json" => {
                println!("Parsing JSON data...");
                println!("Option: {}", option);
                println!("Data: {}", data);
                let json_data: serde_json::Value = serde_json::from_str(&data).ok()?;
                Some(TurtleOutputs::Json(TurtleOutputJson { data: json_data }))
            }
            "yaml" => {
                let yaml_data: serde_yaml::Value = serde_yaml::from_str(&data).ok()?;
                Some(TurtleOutputs::Yaml(TurtleOutputYaml { data: yaml_data }))
            }
            "text" => Some(TurtleOutputs::Text(TurtleOutputText { data })),
            "ast" => Some(TurtleOutputs::Ast(TurtleOutputAst { data })),
            _ => None,
        }
    }
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

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
// #[allow(dead_code)] //for now until we use all variants
pub enum TurtleToken {
    Arrow, // an '->' typically used in function definitions, eg: func foo() -> String {}

    String(String), // string literals
    Number(f64),    // numeric literals
    Boolean(bool),  // a literal True or False

    BraceClose, // a closing brace '}' typically used to complete code blocks or object literals
    BraceOpen,  // an opening brace '{' typically used to start code blocks or object literals
    BracketClose, // a closing bracket ']' typically used to complete array literals
    BracketOpen, // an opening bracket '[' typically used to start array literals
    ParenClose, // a closing parenthesis ')' typically used to complete function calls or group expressions
    ParenOpen, // an opening parenthesis '(' typically used to start function calls or group expressions
    Colon,     // a colon ':' typically used to separate keys and values in objects
    Comma,     // a comma ',' typically used to separate items in arrays or parameters in functions

    CodeBlock(Vec<TurtleToken>),       // a block of code
    CodeCommentSingleLine(String),     // single line comment
    CodeCommentMultiLineOpen(String),  // multi-line comment
    CodeCommentMultiLineClose(String), // multi-line comment close
    Identifier(String),                // variable names
    Builtin {
        name: String,
        args: Vec<TurtleToken>,
    }, // built-in function names
    Keyword(String),                   // if, else, while, for, func, return, break, continue

    // Shell command and arguments
    ShellArg {
        name: String,
    },
    ShellShortArg {
        name: String,
        values: Vec<TurtleToken>,
    },
    ShellLongArg {
        name: String,
        values: Vec<TurtleToken>,
    },
    ShellCommand {
        name: String,
        args: Vec<TurtleToken>,
    },
    ShellComment(String),
    ShellDot,       // represents the current directory '.'
    ShellDoubleDot, // represents the parent directory '..'
    ShellDirectory {
        segments: Vec<String>,
    },
    ShellFile {
        name: String,
        path: String,
        extension: Option<String>,
    },

    Operator(String),           // +, -, *, /, %, ==, !=, <, >, <=, >=, &&, ||, !
    AdditionOperator,           // +
    SubtractionOperator,        // -
    MultiplicationOperator,     // *
    DivisionOperator,           // /
    ModulusOperator,            // %
    EqualOperator,              // ==
    NotEqualOperator,           // !=
    LessThanOperator,           // <
    GreaterThanOperator,        // >
    LessThanOrEqualOperator,    // <=
    GreaterThanOrEqualOperator, // >=
    AndOperator,                // &&
    OrOperator,                 // ||
    NotOperator,                // !
    Semicolon,                  // ;
    Eof,                        // end of file/input
}

#[derive(Debug, Clone, Deserialize, Serialize)]
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
