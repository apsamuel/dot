/// shell expression types
use serde::{Deserialize, Serialize};

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

impl std::fmt::Display for Outputs {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
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
                    serde_json::to_string_pretty(&json.data).map_err(|_| std::fmt::Error)?;
                write!(f, "{}", json_string)
            }
            Outputs::Yaml(yaml) => {
                let yaml_string = serde_yaml::to_string(&yaml.data).map_err(|_| std::fmt::Error)?;
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
    pub fn from_command_response(
        option: &str,
        response: crate::history::CommandResponse,
    ) -> Option<Self> {
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
    CommandResponse(crate::history::CommandResponse),
    #[serde(rename = "turtle_expression")]
    TurtleExpression(Expressions),
}
