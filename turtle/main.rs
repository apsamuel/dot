mod types; // shared structs/enums
mod utils; // utility functions // main shell struct

use clap::Parser; // command line argument parsing

#[tokio::main]
async fn main() {
    let args = crate::types::Arguments::parse();
    let mut shell = crate::types::Shell::new(args.clone());

    loop {
        shell.start();
    }
}
