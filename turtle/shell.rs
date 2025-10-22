#[derive(Debug, Clone)]
pub struct TurtleShell {
    pub config: crate::types::TurtleConfig,
    pub parser: crate::interpreter::TurtleParser,
    pub pid: Option<u32>,
    pub uptime: u64,
    pub paused: bool,
    pub running: bool,
}

impl TurtleShell {
    pub fn new(
        config: crate::types::TurtleConfig,
        parser: crate::interpreter::TurtleParser,
        // pid: Option<u32>,
    ) -> Self {
        TurtleShell {
            config,
            parser,
            pid: None,
            uptime: 0,
            paused: false,
            running: true,
        }
    }

    pub fn start(&mut self) {
        // TODO: implement main shell loop here
    }
}