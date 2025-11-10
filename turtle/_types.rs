use crossterm::style::Color;
// use notify::Watcher;
use serde::{Deserialize, Serialize};
use std::fmt;

static VERSION: &str = "0.1.0";

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

#[derive(Serialize, Deserialize, Debug, Clone)]
pub enum Outputs {
    Table(OutputCsv),
    Json(OutputJson),
    Yaml(OutputYaml),
    Text(OutputText),
    Ast(OutAst),
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

/// outputs for expression results
#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "event")]
pub enum OutputResults {
    #[serde(rename = "command_response")]
    CommandResponse(CommandResponse),
    #[serde(rename = "turtle_expression")]
    TurtleExpression(Expressions),
}

/// a command request to the shell
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct CommandRequest {
    pub id: String,
    pub command: String,
    pub args: Vec<String>,
    pub timestamp: u64,
    // pub event: String,
}

/// a command response from the shell
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct CommandResponse {
    pub id: String,
    pub status: String,
    pub code: i32,
    pub output: String,
    pub errors: String,
    pub timestamp: u64,
    // pub event: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "event")]

/// history event types
pub enum Event {
    // #[serde(rename = "command_request")]
    CommandRequest(CommandRequest),
    // #[serde(rename = "command_response")]
    CommandResponse(CommandResponse),
}

impl fmt::Display for Event {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Event::CommandRequest(req) => write!(
                f,
                "[{}] Command Request: {} {:?}",
                req.timestamp, req.command, req.args
            ),
            Event::CommandResponse(res) => write!(
                f,
                "[{}] Command Response: {} (code: {})",
                res.timestamp, res.output, res.code
            ),
        }
    }
}

/// helper methods for HistoryEvent
impl Event {
    pub fn category(&self) -> &str {
        match self {
            Event::CommandRequest(_) => "CommandRequest",
            Event::CommandResponse(_) => "CommandResponse",
        }
    }

    pub fn as_json(&self) -> serde_json::Value {
        match self {
            Event::CommandRequest(req) => serde_json::to_value(req).unwrap(),
            Event::CommandResponse(res) => serde_json::to_value(res).unwrap(),
        }
    }

    pub fn as_yaml(&self) -> serde_yaml::Value {
        match self {
            Event::CommandRequest(req) => serde_yaml::to_value(req).unwrap(),
            Event::CommandResponse(res) => serde_yaml::to_value(res).unwrap(),
        }
    }

    pub fn as_string(&self) -> String {
        match self {
            Event::CommandRequest(req) => format!("{:?}", req),
            Event::CommandResponse(res) => format!("{:?}", res),
        }
    }

    pub fn as_csv(&self) -> String {
        match self {
            Event::CommandRequest(req) => {
                let mut wtr = csv::Writer::from_writer(vec![]);
                wtr.serialize(req).unwrap();
                let data = String::from_utf8(wtr.into_inner().unwrap()).unwrap();
                data
            }
            Event::CommandResponse(res) => {
                let mut wtr = csv::Writer::from_writer(vec![]);
                wtr.serialize(res).unwrap();
                let data = String::from_utf8(wtr.into_inner().unwrap()).unwrap();
                data
            }
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct History {
    pub debug: bool,
    pub interval: Option<u64>,
    pub path: Option<String>,
    pub events: Option<Vec<Event>>,
}

impl History {
    pub fn new(path: Option<String>, interval: Option<u64>, debug: bool) -> Self {
        if let Some(p) = &path {
            let expanded_path = crate::utils::expand_path(p);
            return History {
                debug,
                path: Some(expanded_path),
                events: Some(Vec::new()),
                interval,
            };
        } else {
            let defaults = crate::config::Defaults::default();
            return History {
                debug,
                path: Some(crate::utils::expand_path(&defaults.history_path)),
                events: Some(Vec::new()),
                interval,
            };
        }
    }

    /// load history from file
    pub fn load(&mut self) -> Option<Vec<crate::types::Event>> {
        if self.path.is_none() {
            println!("❌ History path is not set.");
            return None;
        }

        if let Some(path) = &self.path {
            let content = std::fs::read_to_string(path).ok()?;
            let mut history = Vec::new();
            for line in content.lines() {
                match serde_json::from_str::<crate::types::Event>(line) {
                    Ok(event) => {
                        history.push(event);
                    }
                    Err(_e) => {
                        println!("❌ Failed to parse event from line: {}", line);
                        continue;
                    }
                }
            }

            self.events = Some(history.clone());

            return Some(history.clone());
        }
        None
    }

    /// set up history and load existing events
    pub fn setup(&mut self) {
        if self.events.is_none() {
            self.events = Some(Vec::new());
        }
        // TODO: we should be using the default value here
        self.events = self.load();
    }

    /// add an event to history
    pub fn add(&mut self, event: Event) {
        if let Some(events) = &mut self.events {
            events.push(event);
        }
    }

    /// flush events to file periodically
    pub fn flush(&self) -> std::io::Result<()> {
        use std::io::Write;
        let duration = std::time::Duration::from_secs(self.interval.unwrap_or(60));
        let path = self.path.clone().unwrap();
        let events = self.events.clone().unwrap_or(Vec::new());

        std::thread::spawn(move || {
            loop {
                std::thread::sleep(duration);
                let mut file = std::fs::OpenOptions::new()
                    .create(true)
                    .append(true)
                    .open(&path)
                    .unwrap();
                for event in &events {
                    let json = serde_json::to_string(event).unwrap();

                    writeln!(file, "{}", json).unwrap();
                }
            }
        });
        Ok(())
    }

    /// serialize and save history to file
    pub fn save(&self) -> std::io::Result<()> {
        use std::io::Write;
        let expanded_path = crate::utils::expand_path(self.path.as_ref().unwrap());
        let mut file = std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(expanded_path)?;
        if let Some(events) = &self.events {
            for event in events {
                let json = serde_json::to_string(event).unwrap();
                writeln!(file, "{}", json)?;
            }
            Ok(())
        } else {
            Ok(())
        }
    }

    /// start periodic flushing of history to file
    pub fn start(&mut self) {
        self.setup();
        if let Some(interval) = self.interval {
            self.flush().ok();
            if self.debug {
                println!("✅ History flushing started every {} seconds", interval);
            }
        }
    }
}

/// shell token types
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum Token {
    /// used in function definitions to define their return types, eg: `func foo() -> String { ... }`
    Arrow,

    /// string literals, eg: `"hello"`, `'world'`
    String(String),
    /// numeric literals, eg: `42`, `3.14`
    Number(f64),
    /// a literal `True` or `False`
    Boolean(bool),

    /// a closing brace '}' typically used to complete code blocks or object literals
    BraceClose,
    /// an opening brace '{' typically used to start code blocks or object literals
    BraceOpen,
    /// a closing bracket ']' typically used to complete array literals
    BracketClose,
    /// an opening bracket '[' typically used to start array literals
    BracketOpen,
    /// a closing parenthesis ')' typically used to complete function calls or group expressions
    ParenClose,
    /// an opening parenthesis '(' typically used to start function calls or group expressions
    ParenOpen,
    /// a colon ':' typically used to separate keys and values in objects
    Colon,
    /// a comma ',' typically useseparate items in arrays or parameters in functions
    Comma,

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
        args: String,
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

/// shell expression
#[derive(Debug, Clone, Deserialize, Serialize, PartialEq)]
pub enum Expressions {
    /// A number. ex: `1`, `2`, `3`, ...
    Number(f64),

    /// A string. eg: `"hello"`, `'world'`, ...
    String(String),

    /// A boolean. eg: `True`, `False`
    Boolean(bool),

    /// A list of expressions. eg: `[1, 2, 3]`
    Array(Vec<Expressions>),

    /// An object/map/dictionary. eg: `{ "key": value, ... }`
    Object(Vec<(String, Expressions)>),

    /// An object access expression. eg: `obj.property, obj["key"]`
    ///
    /// supports chainable property access: `obj.prop1.prop2["key"]`
    MemberAccess {
        object: Box<Expressions>,
        property: String,
    },
    /// An assignment expression. eg: `let var = value`
    Assignment {
        name: String,
        value: Box<Expressions>,
    },

    /// An identifier. eg: `some_var`
    Identifier(String),
    /// Unary Operation. eg: `-5`, `!true`
    UnaryOperation { op: String, expr: Box<Expressions> },
    /// Binary Operation. eg: `1 + 2`, `x - 3`
    BinaryOperation {
        left: Box<Expressions>,
        op: String,
        right: Box<Expressions>,
    },
    /// If Control Flow - eg: `if cond { ... } else { ... } or if cond { ... }`
    If {
        condition: Box<Expressions>,
        then_branch: Box<Expressions>,
        else_branch: Option<Box<Expressions>>,
    },
    /// While Loop Control Flow - eg: `while cond { ... }`
    While {
        condition: Box<Expressions>,
        body: Box<Expressions>,
    },
    /// For Loop Control Flow - eg: `for i in iterable { ... }`
    For {
        iterator: String,
        iterable: Box<Expressions>,
        body: Box<Expressions>,
    },
    /// Regular Expression - eg: `/pattern/`
    RegularExpression {
        pattern: String,
        flags: Option<String>,
    },
    /// A loop expression. eg: `loop { ... }`
    Loop { body: Box<Expressions> },
    /// fn <name>(<params>) { ... }
    FunctionDefinition {
        name: String,
        params: Vec<String>,
        body: Box<Vec<Expressions>>,
    },
    /// A call to a user defined function. eg: `func(args, ...)`
    FunctionCall {
        func: String,
        args: Vec<Expressions>,
    },

    /// An expression grouping
    /// eg: `(expr)`
    Grouping { expr: Box<Expressions> },
    /// A block of expressions. eg: `{ expr1; expr2; ... }`
    CodeBlock { expressions: Vec<Expressions> },
    /// A built-in function call. eg: print("hello"), alias, exit, ...
    Builtin { name: String, args: String },
    /// An environment variable access. eg: $HOME, $PATH
    EnvironmentVariable { name: String },
    /// A turtle variable access. eg: @turtle_var
    TurtleVariable {
        name: String,
        value: Box<Expressions>,
    },
    /// A shell command execution. eg: ls -la, echo "hello", ...
    ShellCommand { name: String, args: String },
    /// A shell directory path. eg: ./path/to/dir, ../parent/dir, /absolute/path
    Path { segments: Vec<String> },
}

/// Result of evaluating a shell command
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct CommandEvalResult {
    pub stdout: String,
    pub stderr: String,
    pub code: i32,
}

#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct BuiltinEvalResult {
    pub output: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct NumberEvalResult {
    pub value: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct StringEvalResult {
    pub value: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct BooleanEvalResult {
    pub value: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ObjectEvalResult {
    pub value: std::collections::HashMap<String, Expressions>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ArrayEvalResult {
    pub value: Vec<Expressions>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct AssignmentEvalResult {
    pub name: String,
    pub value: Expressions,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct EnvironmentVariableEvalResult {
    pub name: String,
    pub value: Option<String>, // value can be None if the variable is not set
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TurtleVariableEvalResult {
    pub name: String,
    pub value: Expressions,
}

/// Expression result enum
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub enum EvalResults {
    CommandExpressionResult(CommandEvalResult),
    BuiltinExpressionResult(BuiltinEvalResult),
    NumberExpressionResult(NumberEvalResult),
    StringExpressionResult(StringEvalResult),
    BooleanExpressionResult(BooleanEvalResult),
    ObjectExpressionResult(ObjectEvalResult),
    ArrayExpressionResult(ArrayEvalResult),
    AssignmentExpressionResult(AssignmentEvalResult),
    EnvironmentVariableExpressionResult(EnvironmentVariableEvalResult),
    TurtleVariableExpressionResult(TurtleVariableEvalResult),
}

impl fmt::Display for EvalResults {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            EvalResults::CommandExpressionResult(cmd) => write!(
                f,
                "Exit code: {}\nStdout:\n{}\nStderr:\n{}",
                cmd.code, cmd.stdout, cmd.stderr
            ),
            EvalResults::NumberExpressionResult(num) => write!(f, "{}", num.value),
            EvalResults::StringExpressionResult(string) => {
                write!(f, "{}", string.value)
            }
            EvalResults::BooleanExpressionResult(boolean) => {
                write!(f, "{}", boolean.value)
            }
            EvalResults::AssignmentExpressionResult(assign) => {
                write!(f, "Assigned {} to {:?}", assign.name, assign.value)
            }
            EvalResults::ObjectExpressionResult(obj) => {
                let mut output = String::from("{\n");
                for (key, value) in &obj.value {
                    output.push_str(&format!("  {}: {:?}\n", key, value));
                }
                output.push('}');
                write!(f, "{}", output)
            }
            EvalResults::ArrayExpressionResult(arr) => {
                let mut output = String::from("[\n");
                for value in &arr.value {
                    output.push_str(&format!("  {:?}\n", value));
                }
                output.push(']');
                write!(f, "{}", output)
            }
            EvalResults::EnvironmentVariableExpressionResult(env) => match &env.value {
                Some(val) => write!(f, "{}", val),
                None => write!(f, "{} is not set", env.name),
            },
            EvalResults::BuiltinExpressionResult(builtin) => match &builtin.output {
                Some(val) => write!(f, "{}", val),
                None => write!(f, "No output"),
            },
            EvalResults::TurtleVariableExpressionResult(var) => {
                write!(f, "{:?}", var.value)
            }
        }
    }
}

impl EvalResults {
    pub fn from_shell_command_result(stdout: String, stderr: String, code: i32) -> Self {
        EvalResults::CommandExpressionResult(CommandEvalResult {
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
                std::sync::Arc<std::sync::Mutex<Vec<Event>>>, // history TODO: replace this with history manager (Just pass History  reference)
                Vec<String>,                                  // available builtin names
                Vec<String>,                                  // args
                bool,                                         // debug
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
    pub debug: bool,
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
        debug: bool,
    ) -> Self {
        Builtins {
            builtins,
            env,
            aliases,
            vars,
            debug,
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
        history: std::sync::Arc<std::sync::Mutex<Vec<Event>>>,
        builtin_names: Vec<String>,
        args: Vec<String>,
    ) {
        let debug = self.debug;
        if let Some(builtin) = self.get(name) {
            (builtin.execute)(env, aliases, vars, history, builtin_names, args, debug);
        } else {
            println!("Builtin command '{}' not found", name);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_test() {
        assert!("test".contains("test"));
    }

    #[test]
    fn test_environment() {
        let mut env = crate::config::Environment::new(true);
        // env.setup();
        env.set("TEST_VAR", "test_value");
        assert_eq!(env.get("TEST_VAR"), Some(&"test_value".to_string()));
        env.unset("TEST_VAR");
        assert_eq!(env.get("TEST_VAR"), None);
    }

    #[test]
    fn test_arguments() {
        let args = crate::config::Arguments::new();
        assert!(args.validate());
    }

    #[test]
    fn test_default_config_loads() {
        let yaml_content = r#"
    debug: true
    prompt: ">"
    aliases:
        ll: "ls -la"
    history_size: 1000
    theme: "dark"
    "#;

        let config = crate::config::Config::loads(yaml_content);
        assert!(config.is_some());
        let config = config.unwrap();
        assert_eq!(config.debug, true);
        assert_eq!(config.prompt, Some(">".into()));
        assert_eq!(
            config.aliases,
            Some(vec![("ll".into(), "ls -la".into())].into_iter().collect())
        );
        assert_eq!(config.history_size, Some(1000));
        assert_eq!(config.theme, Some("dark".into()));
    }

    #[test]
    fn test_config_file_loads() {
        let home = dirs::home_dir().unwrap();
        let test_config_path = home.join(".turtle_test_config.yaml");
        let yaml_content = r#"
    debug: true
    prompt: ">"
    aliases:
        ll: "ls -la"
    history_size: 1000
    theme: "dark"
    "#;
        std::fs::write(&test_config_path, yaml_content).unwrap();

        let config = crate::config::Config::load(test_config_path.to_str().unwrap());
        assert!(config.is_some());
        let config = config.unwrap();
        assert_eq!(config.debug, true);
        assert_eq!(config.prompt, Some(">".into()));
        assert_eq!(
            config.aliases,
            Some(vec![("ll".into(), "ls -la".into())].into_iter().collect())
        );
        assert_eq!(config.history_size, Some(1000));
        assert_eq!(config.theme, Some("dark".into()));

        std::fs::remove_file(test_config_path).unwrap();
    }

    #[test]
    fn test_tokenize_primitives() {
        let mut interpreter = crate::lang::Interpreter::new(
            std::sync::Arc::new(std::sync::Mutex::new(std::collections::HashMap::new())),
            std::sync::Arc::new(std::sync::Mutex::new(std::collections::HashMap::new())),
            std::sync::Arc::new(std::sync::Mutex::new(std::collections::HashMap::new())),
            vec![],
            false,
        );
        let input = r#"echo "Hello, World!" -a /path/to/dir"#;
        let tokens = interpreter.tokenize_primitives(input);
        assert_eq!(
            tokens,
            vec![
                crate::types::Token::Identifier("echo".to_string()),
                crate::types::Token::Space,
                crate::types::Token::String("Hello, World!".to_string()),
                crate::types::Token::Space,
                crate::types::Token::Operator("-".to_string()),
                crate::types::Token::Identifier("a".to_string()),
                crate::types::Token::Space,
                crate::types::Token::Operator("/".to_string()),
                crate::types::Token::Identifier("path".to_string()),
                crate::types::Token::Operator("/".to_string()),
                crate::types::Token::Identifier("to".to_string()),
                crate::types::Token::Operator("/".to_string()),
                crate::types::Token::Identifier("dir".to_string()),
                crate::types::Token::Eof,
            ]
        );
    }
}
