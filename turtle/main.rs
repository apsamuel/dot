mod configuration; // configuration loading and environment setup
mod defaults; // default configuration values
mod execution; // execution context
// mod history; // command history logging
// mod input; // input handling (env var and tilde expansion)
mod interpreter; // turtle shell interpreter
mod shell;
mod types; // shared structs/enums
mod utils; // utility functions // main shell struct

// mod _builtin; // built-in commands
mod themes;
mod widgets; // TUI widgets // theme management

mod prompt; // prompt handling

use clap::Parser; // command line argument parsing

#[tokio::main]
async fn main() {
    let args = crate::types::Arguments::parse();
    let mut shell = crate::shell::Shell::new(args.clone());

    loop {
        shell.start();
    }
}
