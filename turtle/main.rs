/// Turtle Shell - A command-line shell powered by language models
/// Copyright (c) 2025 Aaron P. Samuel
/// Licensed under the MIT License <LICENSE-MIT or http://opensource.org/licenses/MIT>
/// SPDX-License-Identifier: MIT
/// See LICENSE for details.
///

/// constants used across the turtle project
mod constants;

/// configure turtle from args, environment variables and/or config files
mod config;

/// Turtle language model interactions
mod lang;

/// language tokens and tokenizer
mod tokens;

/// turtle expressions and parsing
mod expressions;

/// execution context
mod context;

/// shell theming
mod style;

/// shell built-in commands
mod builtins;

/// command history management
mod history;

// main shell functionality
mod shell;

// shell utility functions
mod utils;

/// Entry point for the Turtle shell
#[tokio::main]
async fn main() {
    let args = crate::config::Arguments::new();
    let mut shell = crate::shell::Shell::new(args.clone());

    loop {
        shell.start();
    }
}
