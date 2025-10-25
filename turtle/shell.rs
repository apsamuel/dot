// static DEFAULT_ENV_VARS: &[(&str, &str)] = &[
//     ("PATH", "/usr/local/bin:/usr/bin:/bin"),
//     ("HOME", "/home/user"),
//     ("LANG", "en_US.UTF-8"),
//     ("TERM", "xterm-256color"),
// ];

#[derive(Debug, Clone)]
pub struct TurtleShell {
    // pub debug: bool,
    pub config: Option<crate::types::TurtleConfig>,
    pub args: Option<crate::types::TurtleArgs>,
    pub interpreter: crate::interpreter::TurtleInterpreter,
    pub pid: Option<u32>,
    pub uptime: u64,
    pub paused: bool,
    pub running: bool,
    history: Vec<crate::types::HistoryEvent>,
    env: std::collections::HashMap<String, String>,
    aliases: std::collections::HashMap<String, String>,
}

impl TurtleShell {
    fn _reload(&self) -> crate::types::TurtleConfig {
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

    fn _read_input(&self) -> String {
        // Read input from user
        String::new() // Placeholder
    }

    pub fn new(
        config: crate::types::TurtleConfig,
        args: crate::types::TurtleArgs,
        interpreter: crate::interpreter::TurtleInterpreter,
        // debug: bool,
        // pid: Option<u32>,
    ) -> Self {
        // let debug = config.debug || args.debug;
        let config = Some(config);
        let args = Some(args);
        let history = Vec::new();
        let aliases = std::collections::HashMap::new();
        let env = std::collections::HashMap::new();

        TurtleShell {
            config,
            args,
            history,
            env,
            aliases,
            interpreter,
            pid: None,
            uptime: 0,
            paused: false,
            running: true,
        }
    }

    pub fn _start(&mut self) {
        // TODO: implement main shell loop here
        self.setup();
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

    /// Set up the shell environment variables
    fn setup_environment(&mut self) -> u64 {
        let _start = crate::utils::now_unix();
        let user_env = crate::utils::build_user_environment();
        for (key, value) in user_env {
            if Some(self.args.as_ref().unwrap().debug) == Some(true) {
                eprintln!("Setting environment variable: {}={}", key, value);
            }

            self.env.insert(key, value);
        }
        let _end = crate::utils::now_unix();
        return _end - _start;
    }

    /// Set up aliases for the shell
    fn setup_aliases(&mut self) -> u64 {
        // Load and set up aliases for the shell
        0
    }

    /// Set up command history for the shell
    fn setup_history(&mut self) -> u64 {
        // Load command history for the shell
        0
    }

    /// Set up the shell
    pub fn setup(&mut self) -> u64 {
        let _start = crate::utils::now_unix();
        self.pid = std::process::id().into();
        self.running = true;
        self.paused = false;
        self.setup_environment();
        self.setup_aliases();
        self.setup_history();
        let _end = crate::utils::now_unix();
        return _end - _start;
    }
}

// static DEFAULT_ENV_VARS: &[(&str, &str)] = &[
//     ("PATH", "/usr/local/bin:/usr/bin:/bin"),
//     ("HOME", "/home/user"),
//     ("LANG", "en_US.UTF-8"),
//     ("TERM", "xterm-256color"),
// ];
