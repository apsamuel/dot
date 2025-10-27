// use crate::utils;

#[derive(Debug, Clone)]
pub struct TurtleShell {
    debug: bool,
    pub args: Option<crate::types::TurtleArgs>,
    pub config: Option<crate::types::TurtleConfig>,
    pub interpreter: crate::interpreter::TurtleInterpreter,
    pub context: crate::execution::TurtleExecutionContext,
    pub pid: Option<u32>,
    pub uptime: u64,
    pub paused: bool,
    pub running: bool,
    // history: Vec<crate::types::HistoryEvent>,
    // editor: rustyline::DefaultEditor,
    history: Vec<serde_json::Value>,
    env: std::collections::HashMap<String, String>,
    aliases: std::collections::HashMap<String, String>,
    tokens: Vec<Vec<crate::types::TurtleToken>>,
    expressions: Vec<crate::types::TurtleExpression>,
}

impl TurtleShell {
    fn get_readline(&self) -> rustyline::DefaultEditor {
        let config = rustyline::config::Config::builder()
            // .history_ignore_dups(true)
            // .history_ignore_space(true)
            // .completion_type(rustyline::config::CompletionType::List)
            .edit_mode(rustyline::config::EditMode::Vi)
            .build();
        let rl = rustyline::DefaultEditor::with_config(config);
        rl.unwrap()
    }

    fn load_aliases(&self) -> std::collections::HashMap<String, String> {
        let mut aliases = std::collections::HashMap::new();
        if let Some(cfg) = &self.config {
            if let Some(turtle_aliases) = &cfg.aliases {
                for (key, value) in turtle_aliases {
                    aliases.insert(key.clone(), value.clone());
                }
            }
        }
        aliases
    }

    fn load_config(&self) -> crate::types::TurtleConfig {
        // Load configuration from file or environment variables
        crate::config::load_config_from_path(
            self.args
                .as_ref()
                .and_then(|args| args.config.as_ref())
                .unwrap_or(&crate::defaults::get_defaults().config_path),
        )
        .unwrap_or_else(|| crate::types::TurtleConfig {
            debug: false,
            prompt: None,
            aliases: None,
            history_size: None,
            theme: None,
        })
    }

    pub fn retrieve_history(&mut self) -> std::io::Result<Vec<serde_json::Value>> {
        let history = crate::history::load_history()?;
        Ok(history)
    }

    fn _read_input(&self) -> String {
        String::new() // Placeholder
    }

    pub fn new(args: crate::types::TurtleArgs) -> Self {
        let defaults = crate::defaults::get_defaults();
        let args = Some(args);

        let config_path = args
            .as_ref()
            .and_then(|args| args.config.as_ref())
            .unwrap_or(&defaults.config_path);

        let config = crate::config::load_config_from_path(config_path);
        let debug = args.as_ref().unwrap().debug
            || config.as_ref().map(|c| c.debug).unwrap_or(false)
            || defaults.debug;

        let history = Vec::new();
        let aliases = std::collections::HashMap::new();
        let env = std::collections::HashMap::new();
        let context = crate::execution::TurtleExecutionContext::new();
        let interpreter = crate::interpreter::TurtleInterpreter::new();

        if debug {
            println!(
                "🐢 Initializing TurtleShell with config: {:?} and args {:?}",
                config, args
            );
        }

        TurtleShell {
            debug,
            config: config.clone(),
            args,
            history,
            env,
            aliases,
            interpreter,
            context,
            pid: None,
            uptime: 0,
            paused: false,
            running: true,
            tokens: Vec::new(),
            expressions: Vec::new(),
        }
    }

    /// Set up the shell environment variables
    fn setup_environment(&mut self) -> u128 {
        let _start = crate::utils::this_instant();
        let user_env = crate::utils::build_user_environment();
        for (key, value) in user_env {
            self.env.insert(key, value);
        }
        let _elapsed = _start.elapsed();
        return _elapsed.as_millis();
    }

    /// Set up aliases for the shell
    fn setup_aliases(&mut self) -> u128 {
        // Load and set up aliases for the shell
        let _start = crate::utils::this_instant();
        self.aliases = self.load_aliases();
        let _elapsed = _start.elapsed();
        return _elapsed.as_millis();
    }

    /// Set up command history for the shell
    fn setup_history(&mut self) -> u128 {
        // Load command history for the shell
        let _start = crate::utils::this_instant();
        self.history = self.retrieve_history().unwrap_or_default();
        let _elapsed = _start.elapsed();
        return _elapsed.as_millis();
    }

    /// Set up the shell
    pub fn setup(&mut self) -> std::collections::HashMap<String, u128> {
        let _start = crate::utils::this_instant();
        self.pid = std::process::id().into();
        self.running = true;
        self.paused = false;
        let setup_environment_duration = self.setup_environment();
        let setup_aliases_duration = self.setup_aliases();
        let setup_history_duration = self.setup_history();
        let _elapsed = _start.elapsed();
        if self.debug {
            println!(
                "🐢 setup completed in {} milliseconds",
                _elapsed.as_millis()
            );
        }
        return std::collections::HashMap::from([
            ("setup_environment".into(), setup_environment_duration),
            ("setup_aliases".into(), setup_aliases_duration),
            ("setup_history".into(), setup_history_duration),
            ("total".into(), _elapsed.as_millis()),
        ]);
    }

    // Reload the shell configuration
    pub fn reload(&self) -> crate::types::TurtleConfig {
        self.load_config()
    }

    /// Start the shell main loop
    pub fn start(&mut self) {
        // TODO: implement main shell loop here
        self.setup();
        let start = crate::utils::this_instant();
        let mut editor = self.get_readline();
        let default_prompt = crate::defaults::get_defaults().prompt;
        let default_theme = crate::defaults::get_defaults().theme;
        crate::themes::apply_theme(&mut std::io::stdout(), &default_theme).ok();

        loop {
            // check if a command was provided via args
            if let Some(command) = self.args.as_ref().and_then(|args| args.command.as_ref()) {
                println!("Executing command from args: {}", command);
                let tokens = self.interpreter.tokenize(command);
                if self.debug {
                    println!("Tokens: {:?}", tokens);
                }
                let expr = self.interpreter.interpret();
                let result = self.context.eval(expr.clone());
                if let Some(res) = result {
                    if self.debug {
                        println!("Result: {:?}", res);
                    }
                }
            }

            // get our prompt from the configuration file, or use the default
            let prompt = self
                .config
                .as_ref()
                .and_then(|cfg| cfg.prompt.as_ref())
                .unwrap_or(&default_prompt);

            let readline = editor.readline(prompt);

            // get user input
            let input = match readline {
                Ok(line) => line,
                Err(rustyline::error::ReadlineError::Interrupted) => {
                    println!("^C");
                    continue;
                }
                Err(rustyline::error::ReadlineError::Eof) => {
                    println!("^D");
                    break;
                }
                Err(err) => {
                    println!("Error: {:?}", err);
                    break;
                }
            };

            // trim input
            let input = input.trim();

            // skip empty input
            if input.is_empty() {
                continue;
            }

            // shell logic here
            // e.g., read input, interpret commands, manage history, etc.
            let tokens = self.interpreter.tokenize(input);
            if self.debug {
                println!("Tokens: {:?}", tokens);
            }
            self.tokens.push(tokens.clone());
            let expr = self.interpreter.interpret();

            self.expressions.push(expr.clone().unwrap());
            let result = self.context.eval(expr.clone());
            if let Some(res) = result {
                if self.debug {
                    println!("Result: {:?}", res);
                }
            }
        }
        let elapsed = start.elapsed();
        if self.debug {
            println!(
                "🐢 shell main loop exited after {} milliseconds",
                elapsed.as_millis()
            );
        }
    }
}
