use clap::Parser;
use crossterm::style::Color;
use serde::{Deserialize, Serialize};
use std::fmt;

/// shell configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub debug: bool,
    pub prompt: Option<String>,
    pub aliases: Option<std::collections::HashMap<String, String>>,
    pub history_size: Option<usize>,
    pub theme: Option<String>,
}

/// shell arguments
#[derive(Parser, Clone, Debug, Serialize, Deserialize)]
#[command(name = "turtle", about = "A simple shell implemented in Rust")]
pub struct Arguments {
    /// enable debugging for the shell
    #[arg(short, long, help = "Enable debugging")]
    pub debug: bool,

    /// show version information
    #[arg(short, long, help = "Show version and exit")]
    pub version: bool,

    /// configuration file path
    #[arg(long, help = "Config File", default_value = "~/.turtle.yaml")]
    pub config: Option<String>,

    /// command to execute in non-interactive mode
    #[arg(long, help = "Non-Interactive Command")]
    pub command: Option<String>,

    /// output format
    #[arg(
        short,
        long,
        help = "format output: table, json, yaml, text, ast",
        default_value = "table"
    )]
    pub format: Option<String>,
}

/// shell theme
#[derive(Debug, Clone)]
pub struct Theme {
    pub foreground: Color,
    pub background: Color,
    pub text: Color,
    pub cursor: Color,
    pub selection: Color,
}

/// shell prompt
pub struct Prompt<'a> {
    template: &'a str,
}

/// defines the context for rendering the prompt
#[derive(Serialize, Deserialize)]
pub struct PromptContext {
    pub user: String,
    pub host: String,
    pub cwd: String,
    pub time: String,
    pub turtle: String,
}

impl<'a> Prompt<'a> {
    pub fn new(template: &'a str) -> Self {
        Prompt { template }
    }

    pub fn context(&self) -> PromptContext {
        PromptContext {
            user: whoami::username(),
            host: whoami::fallible::hostname().unwrap_or_else(|_| "?".into()),
            cwd: std::env::current_dir()
                .map(|path| path.display().to_string())
                .unwrap_or_else(|_| "?".to_string()),
            time: chrono::Local::now().format("%H:%M:%S").to_string(),
            turtle: "🐢".into(),
        }
    }

    pub fn render(&mut self) -> String {
        let context = self.context();
        let mut engine = tinytemplate::TinyTemplate::new();
        let template = self.template;
        engine.add_template("prompt", template);
        engine
            .render("prompt", &context)
            .unwrap_or_else(|_| template.to_string())
    }
}

impl fmt::Display for Outputs {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Outputs::Table(table) => {
                let mut output = String::new();
                output.push_str(&table.headers.join("\t"));
                output.push('\n');
                for row in &table.data {
                    output.push_str(&row.join("\t"));
                    output.push('\n');
                }
                write!(f, "{}", output)
            }
            Outputs::Json(json) => {
                let json_string =
                    serde_json::to_string_pretty(&json.data).map_err(|_| fmt::Error)?;
                write!(f, "{}", json_string)
            }
            Outputs::Yaml(yaml) => {
                let yaml_string = serde_yaml::to_string(&yaml.data).map_err(|_| fmt::Error)?;
                write!(f, "{}", yaml_string)
            }
            Outputs::Text(text) => {
                write!(f, "{}", text.data)
            }
            Outputs::Ast(ast) => {
                write!(f, "{}", ast.data)
            }
        }
    }
}

/// shell output formats
impl Outputs {
    pub fn from_command_response(option: &str, response: CommandResponse) -> Option<Self> {
        match option {
            "table" => {
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
                Some(Outputs::Table(OutputCsv {
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
                Some(Outputs::Json(OutputJson { data: json_data }))
            }
            "yaml" => {
                let yaml_data = serde_yaml::to_string(&response).ok()?;
                let yaml_data: serde_yaml::Value = serde_yaml::from_str(&yaml_data).ok()?;
                Some(Outputs::Yaml(OutputYaml { data: yaml_data }))
            }
            "text" => Some(Outputs::Text(OutputText {
                data: response.output,
            })),
            "ast" => Some(Outputs::Ast(OutAst {
                data: response.output,
            })),
            _ => None,
        }
    }

    pub fn _from_turtle_expression(expression: Expressions) -> Option<Self> {
        match expression {
            Expressions::String(s) => Some(Outputs::Text(OutputText { data: s })),
            Expressions::Number(n) => Some(Outputs::Text(OutputText {
                data: n.to_string(),
            })),
            Expressions::Boolean(b) => Some(Outputs::Text(OutputText {
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
                Some(Outputs::Table(OutputCsv {
                    headers,
                    data: rows,
                }))
            }
            "json" => {
                println!("Parsing JSON data...");
                println!("Option: {}", option);
                println!("Data: {}", data);
                let json_data: serde_json::Value = serde_json::from_str(&data).ok()?;
                Some(Outputs::Json(OutputJson { data: json_data }))
            }
            "yaml" => {
                let yaml_data: serde_yaml::Value = serde_yaml::from_str(&data).ok()?;
                Some(Outputs::Yaml(OutputYaml { data: yaml_data }))
            }
            "text" => Some(Outputs::Text(OutputText { data })),
            "ast" => Some(Outputs::Ast(OutAst { data })),
            _ => None,
        }
    }
}

/// CSV compatible output
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct OutputCsv {
    pub headers: Vec<String>,
    pub data: Vec<Vec<String>>,
}

/// YAML compatible output
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct OutputYaml {
    pub data: serde_yaml::Value,
}

/// JSON compatible output
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct OutputJson {
    pub data: serde_json::Value,
}

/// Plain text output
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct OutputText {
    pub data: String,
}

/// AST output
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct OutAst {
    pub data: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub enum Outputs {
    Table(OutputCsv),
    Json(OutputJson),
    Yaml(OutputYaml),
    Text(OutputText),
    Ast(OutAst),
}

/// outputs for expression results
#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "event")]
pub enum OutputResults {
    #[serde(rename = "command_response")]
    CommandResponse(CommandResponse),
    #[serde(rename = "turtle_expression")]
    TurtleExpression(Expressions),
}

/// represents a command request sent to the shell
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct CommandRequest {
    pub id: String,
    pub command: String,
    pub args: Vec<String>,
    pub timestamp: u64,
    pub event: String,
}

/// represents a command response from the shell
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

/// history event types
///
/// `command_request`: constructed when a command is issued
///
/// `command_response`: constructed when a command returns
#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "event")]
pub enum HistoryEvent {
    #[serde(rename = "command_request")]
    CommandRequest(CommandRequest),
    #[serde(rename = "command_response")]
    CommandResponse(CommandResponse),
}

/// implement Display for HistoryEvent
impl fmt::Display for HistoryEvent {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            HistoryEvent::CommandRequest(req) => write!(
                f,
                "[{}] Command Request: {} {:?}",
                req.timestamp, req.command, req.args
            ),
            HistoryEvent::CommandResponse(res) => write!(
                f,
                "[{}] Command Response: {} (code: {})",
                res.timestamp, res.output, res.code
            ),
        }
    }
}

/// helper methods for HistoryEvent
impl HistoryEvent {
    pub fn get_events(&self, path: &str) -> Option<Vec<HistoryEvent>> {
        let data = std::fs::read_to_string(path).ok()?;
        let mut events = Vec::new();
        for line in data.lines() {
            let event: HistoryEvent = serde_json::from_str(line).ok()?;
            events.push(event);
        }
        Some(events)
    }

    pub fn get_event_type(&self) -> &str {
        match self {
            HistoryEvent::CommandRequest(_) => "command_request",
            HistoryEvent::CommandResponse(_) => "command_response",
        }
    }

    pub fn get_events_by_type(history: &Vec<HistoryEvent>, event_type: &str) -> Vec<HistoryEvent> {
        history
            .iter()
            .filter(|event| event.get_event_type() == event_type)
            .cloned()
            .collect()
    }

    pub fn to_json(&self) -> serde_json::Value {
        match self {
            HistoryEvent::CommandRequest(req) => serde_json::to_value(req).unwrap(),
            HistoryEvent::CommandResponse(res) => serde_json::to_value(res).unwrap(),
        }
    }

    pub fn to_yaml(&self) -> serde_yaml::Value {
        match self {
            HistoryEvent::CommandRequest(req) => serde_yaml::to_value(req).unwrap(),
            HistoryEvent::CommandResponse(res) => serde_yaml::to_value(res).unwrap(),
        }
    }

    pub fn to_string(&self) -> String {
        match self {
            HistoryEvent::CommandRequest(req) => format!("{:?}", req),
            HistoryEvent::CommandResponse(res) => format!("{:?}", res),
        }
    }

    pub fn to_csv(&self) -> String {
        match self {
            HistoryEvent::CommandRequest(req) => {
                let mut wtr = csv::Writer::from_writer(vec![]);
                wtr.serialize(req).unwrap();
                let data = String::from_utf8(wtr.into_inner().unwrap()).unwrap();
                data
            }
            HistoryEvent::CommandResponse(res) => {
                let mut wtr = csv::Writer::from_writer(vec![]);
                wtr.serialize(res).unwrap();
                let data = String::from_utf8(wtr.into_inner().unwrap()).unwrap();
                data
            }
        }
    }

    pub fn from_json(value: &serde_json::Value) -> Option<Self> {
        if let Some(event_type) = value.get("event").and_then(|v| v.as_str()) {
            match event_type {
                "command_request" => {
                    let req: CommandRequest = serde_json::from_value(value.clone()).ok()?;
                    Some(HistoryEvent::CommandRequest(req))
                }
                "command_response" => {
                    let res: CommandResponse = serde_json::from_value(value.clone()).ok()?;
                    Some(HistoryEvent::CommandResponse(res))
                }
                _ => None,
            }
        } else {
            None
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
// #[allow(dead_code)] //for now until we use all variants
pub enum Token {
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

    CodeBlock(Vec<Token>),             // a block of code
    CodeCommentSingleLine(String),     // single line comment
    CodeCommentMultiLineOpen(String),  // multi-line comment
    CodeCommentMultiLineClose(String), // multi-line comment close
    KeywordOpen(String),               // keywords that open blocks: if, else, while, for, func
    KeywordClose(String),              // keywords that close blocks: end, done, return
    Keyword(String),                   // if, else, while, for, func, return, break, continue
    Identifier(String),                // variable names
    Builtin {
        name: String,
        args: Vec<Token>,
    }, // built-in function names
    // Keyword(String),                   // if, else, while, for, func, return, break, continue

    // Shell command and arguments
    ShellArg {
        name: String,
    },
    ShellShortArg {
        name: String,
        values: Vec<Token>,
    },
    ShellLongArg {
        name: String,
        values: Vec<Token>,
    },
    ShellCommand {
        name: String,
        // args: Vec<TurtleToken>,
        // instead of using Vec<TurtleToken>, we can use a single String and parse it later using better shell argument parsing
        args: String,
        // args: String,
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
    Space,   // single space
    Tab,     // tab character
    Newline, // newline character
    // Whitespace, // spaces, tabs, newlines
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

#[derive(Debug, Clone, Deserialize, Serialize, PartialEq)]
#[allow(dead_code)] //for now until we use all variants
pub enum Expressions {
    // 1, 2, 3, ...
    Number(f64),
    // "hello", 'world', ...
    String(String),
    // true, false
    Boolean(bool),
    // [1, 2, 3]
    Array(Vec<Expressions>),
    // { "key": value, ... }
    Object(Vec<(String, Expressions)>),
    // obj.property
    MemberAccess {
        object: Box<Expressions>,
        property: String,
    },
    // var = value, let var = value
    Assignment {
        name: String,
        value: Box<Expressions>,
    },
    // Variables and operations
    Identifier(String),
    // Unary Operation - ex: -5, !true
    UnaryOperation {
        op: String,
        expr: Box<Expressions>,
    },
    // Binary Operation - ex: 1 + 2, x - 3
    BinaryOperation {
        left: Box<Expressions>,
        op: String,
        right: Box<Expressions>,
    },
    // If Control Flow - ex: if cond { ... } else { ... } or if cond { ... }
    If {
        condition: Box<Expressions>,
        then_branch: Box<Expressions>,
        else_branch: Option<Box<Expressions>>,
    },
    // While Loop Control Flow - ex: while cond { ... }
    While {
        condition: Box<Expressions>,
        body: Box<Expressions>,
    },
    For {
        iterator: String,
        iterable: Box<Expressions>,
        body: Box<Expressions>,
    },
    RegularExpression {
        pattern: String,
        flags: Option<String>,
    },
    Loop {
        body: Box<Expressions>,
    },
    FunctionDefinition {
        name: String,
        params: Vec<String>,
        body: Box<Vec<Expressions>>,
    },
    FunctionCall {
        func: String,
        args: Vec<Expressions>,
    },
    CodeBlock {
        expressions: Vec<Expressions>,
    },

    Builtin {
        name: String,
        args: String,
    },
    EnvironmentVariable {
        name: String,
    },
    TurtleVariable {
        name: String,
        value: Box<Expressions>,
    },
    ShellCommand {
        name: String,
        args: String,
    },
    Path {
        segments: Vec<String>,
    },
}

/// Result of evaluating a shell command
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct CommandExpressionResult {
    pub stdout: String,
    pub stderr: String,
    pub code: i32,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct BuiltinExpressionResult {
    pub output: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct NumberExpressionResult {
    pub value: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct StringExpressionResult {
    pub value: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct BooleanExpressionResult {
    pub value: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ObjectExpressionResult {
    pub value: std::collections::HashMap<String, Expressions>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ArrayExpressionResult {
    pub value: Vec<Expressions>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct AssignmentExpressionResult {
    pub name: String,
    pub value: Expressions,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct EnvironmentVariableExpressionResult {
    pub name: String,
    pub value: Option<String>, // value can be None if the variable is not set
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TurtleVariableExpressionResult {
    pub name: String,
    pub value: Expressions,
}

/// Expression result enum
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum ExpressionResults {
    CommandExpressionResult(CommandExpressionResult),
    BuiltinExpressionResult(BuiltinExpressionResult),
    NumberExpressionResult(NumberExpressionResult),
    StringExpressionResult(StringExpressionResult),
    BooleanExpressionResult(BooleanExpressionResult),
    ObjectExpressionResult(ObjectExpressionResult),
    ArrayExpressionResult(ArrayExpressionResult),
    AssignmentExpressionResult(AssignmentExpressionResult),
    EnvironmentVariableExpressionResult(EnvironmentVariableExpressionResult),
    TurtleVariableExpressionResult(TurtleVariableExpressionResult),
}

impl fmt::Display for ExpressionResults {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ExpressionResults::CommandExpressionResult(cmd) => write!(
                f,
                "Exit code: {}\nStdout:\n{}\nStderr:\n{}",
                cmd.code, cmd.stdout, cmd.stderr
            ),
            ExpressionResults::NumberExpressionResult(num) => write!(f, "{}", num.value),
            ExpressionResults::StringExpressionResult(string) => {
                write!(f, "{}", string.value)
            }
            ExpressionResults::BooleanExpressionResult(boolean) => {
                write!(f, "{}", boolean.value)
            }
            ExpressionResults::AssignmentExpressionResult(assign) => {
                write!(f, "Assigned {} to {:?}", assign.name, assign.value)
            }
            ExpressionResults::ObjectExpressionResult(obj) => {
                let mut output = String::from("{\n");
                for (key, value) in &obj.value {
                    output.push_str(&format!("  {}: {:?}\n", key, value));
                }
                output.push('}');
                write!(f, "{}", output)
            }
            ExpressionResults::ArrayExpressionResult(arr) => {
                let mut output = String::from("[\n");
                for value in &arr.value {
                    output.push_str(&format!("  {:?}\n", value));
                }
                output.push(']');
                write!(f, "{}", output)
            }
            ExpressionResults::EnvironmentVariableExpressionResult(env) => match &env.value {
                Some(val) => write!(f, "{}", val),
                None => write!(f, "{} is not set", env.name),
            },
            ExpressionResults::BuiltinExpressionResult(builtin) => match &builtin.output {
                Some(val) => write!(f, "{}", val),
                None => write!(f, "No output"),
            },
            ExpressionResults::TurtleVariableExpressionResult(var) => {
                write!(f, "{:?}", var.value)
            }
        }
    }
}

impl ExpressionResults {
    pub fn from_shell_command_result(stdout: String, stderr: String, code: i32) -> Self {
        ExpressionResults::CommandExpressionResult(CommandExpressionResult {
            stdout,
            stderr,
            code,
        })
    }
}

/// shell builtin command
pub struct Builtin {
    pub name: String,
    pub description: String,
    pub help: String,
    pub execute: Box<
        dyn Fn(
                std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>, // env
                std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>, // aliases
                std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, Expressions>>>, // vars
                std::sync::Arc<std::sync::Mutex<Vec<HistoryEvent>>>, // history
                Vec<String>,                                         // available builtin names
                Vec<String>,                                         // args
                                                                     // TODO: consider adding history and the implications of that...
            ) + Send
            + Sync
            + 'static,
    >,
}

impl Builtin {
    pub fn get<'a>(name: &str, builtins: &'a [Builtin]) -> Option<&'a Builtin> {
        builtins.iter().find(|builtin| builtin.name == name)
    }

    pub fn get_builtin(name: &str, builtins: Vec<Builtin>) -> Option<Builtin> {
        for builtin in builtins {
            if builtin.name == name {
                return Some(builtin);
            }
        }
        None
    }
}

impl std::fmt::Debug for Builtin {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("TurtleBuiltin")
            .field("name", &self.name)
            .field("description", &self.description)
            .field("help", &self.help)
            .finish()
    }
}

// #[derive(Debug, Clone)]
pub struct Builtins {
    pub builtins: Vec<Builtin>,
    pub env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    pub aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    pub vars: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, Expressions>>>,
}

impl std::fmt::Debug for Builtins {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("TurtleBuiltins")
            .field("builtins", &self.builtins)
            .finish()
    }
}

impl Builtins {
    pub fn new(
        builtins: Vec<Builtin>,
        env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        vars: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, Expressions>>>,
    ) -> Self {
        Builtins {
            builtins,
            env,
            aliases,
            vars,
        }
    }

    pub fn get(&self, name: &str) -> Option<&Builtin> {
        self.builtins.iter().find(|b| b.name == name)
    }

    pub fn list(&self) -> Vec<String> {
        self.builtins.iter().map(|b| b.name.clone()).collect()
    }

    pub fn exec(
        &self,
        name: &str,
        vars: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, Expressions>>>,
        env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        history: std::sync::Arc<std::sync::Mutex<Vec<HistoryEvent>>>,
        builtin_names: Vec<String>,
        args: Vec<String>,
    ) {
        if let Some(builtin) = self.get(name) {
            (builtin.execute)(env, aliases, vars, history, builtin_names, args);
        } else {
            println!("Builtin command '{}' not found", name);
        }
    }
}
