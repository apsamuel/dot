#[derive(Debug, Clone)]
pub struct TurtleShell {
    pub debug: bool,
    pub config: crate::types::TurtleConfig,
    pub parser: crate::interpreter::TurtleParser,
    pub pid: Option<u32>,
    pub uptime: u64,
    pub paused: bool,
    pub running: bool,
}

impl TurtleShell {
    fn load_config(&self) -> crate::types::TurtleConfig {
        // Load configuration from file or environment variables
        crate::config::load_config(self.config.debug).unwrap_or_else(|| {
            crate::types::TurtleConfig {
                debug: false,
                prompt: None,
                aliases: None,
                history_size: None,
                theme: None,
            }
        })
    }
    pub fn new(
        config: crate::types::TurtleConfig,
        parser: crate::interpreter::TurtleParser,
        debug: bool,
        // pid: Option<u32>,
    ) -> Self {
        TurtleShell {
            debug,
            config,
            parser,
            pid: None,
            uptime: 0,
            paused: false,
            running: true,
            // debug,
        }
    }

    pub fn start(&mut self) {
        // TODO: implement main shell loop here
        loop {
            if !self.running {
                break;
            }
            // shell logic here
        }
    }
}
