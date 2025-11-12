use serde::{Deserialize, Serialize};
/// Tokens used in the Turtle language
///
/// Copyright (c) 2025 Aaron P. Samuel
///
/// Licensed under the MIT License <LICENSE-MIT or http://opensource.org/licenses/MIT>
///
/// **SPDX-License-Identifier**: MIT
///
/// See LICENSE for details.
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
