#[derive(Debug, Clone)]
pub struct TurtleShell {
    pub _debug: bool,
    _history: Vec<crate::types::HistoryEvent>,
    _env: std::collections::HashMap<String, String>,
    _aliases: std::collections::HashMap<String, String>,
    pub _config: Option<crate::types::TurtleConfig>,
    pub _args: Option<crate::types::TurtleArgs>,
    pub _interpreter: crate::interpreter::TurtleInterpreter,
    pub _pid: Option<u32>,
    pub _uptime: u64,
    pub _paused: bool,
    pub _running: bool,
}

impl TurtleShell {
    fn _reload(&self) -> crate::types::TurtleConfig {
        // Load configuration from file or environment variables
        crate::config::load_config(self._config.as_ref().unwrap().debug).unwrap_or_else(|| {
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

    fn _read_input(&self) -> String {
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
            _config: config,
            _args: args,
            _debug: debug,
            _history: history,
            _env: env,
            _aliases: aliases,
            _interpreter: interpreter,
            _pid: None,
            _uptime: 0,
            _paused: false,
            _running: true,
            // debug,
        }
    }

    pub fn _start(&mut self) {
        // TODO: implement main shell loop here
        let _start = crate::utils::now_unix();
        loop {
            if !self._running {
                break;
            }

            if !self._paused {
                // Read input, parse, execute commands, etc.
            }
            // shell logic here
        }
    }
}
