#[derive(Debug, Clone)]
pub struct TurtleShell {
    pub debug: bool,
    history: Vec<crate::types::HistoryEvent>,
    env: std::collections::HashMap<String, String>,
    aliases: std::collections::HashMap<String, String>,
    pub config: Option<crate::types::TurtleConfig>,
    pub args: Option<crate::types::TurtleArgs>,
    pub interpreter: crate::interpreter::TurtleInterpreter,
    pub pid: Option<u32>,
    pub uptime: u64,
    pub paused: bool,
    pub running: bool,
}

impl TurtleShell {
    fn reload(&self) -> crate::types::TurtleConfig {
        // Load configuration from file or environment variables
        crate::config::load_config(self.config.as_ref().unwrap().debug).unwrap_or_else(|| {
            crate::types::TurtleConfig {
                // history: None,
                debug: false,
                prompt: None,
                aliases: None,
                history_size: None,
                theme: None,
            }
        })
    }

    fn read_input(&self) -> String {
        // Read input from user
        String::new() // Placeholder
    }

    pub fn new(
        config: crate::types::TurtleConfig,
        args: crate::types::TurtleArgs,
        interpreter: crate::interpreter::TurtleInterpreter,
        debug: bool,
        // pid: Option<u32>,
    ) -> Self {
        let debug = config.debug || debug;
        let config = Some(config);
        let args = Some(args);
        let history = Vec::new();
        let aliases = std::collections::HashMap::new();
        let env = std::collections::HashMap::new();

        // if

        TurtleShell {
            config,
            args,
            debug,
            history,
            env,
            aliases,
            interpreter,
            pid: None,
            uptime: 0,
            paused: false,
            running: true,
            // debug,
        }
    }

    pub fn start(&mut self) {
        // TODO: implement main shell loop here
        let _start = crate::utils::now_unix();
        loop {
            if !self.running {
                break;
            }

            if !self.paused {
                // Read input, parse, execute commands, etc.
            }
            // shell logic here
        }
    }
}
