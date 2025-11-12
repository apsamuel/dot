/// Shell structure and implementation
///
/// Copyright (c) 2025 Aaron P. Samuel
///
/// Licensed under the MIT License <LICENSE-MIT or http://opensource.org/licenses/MIT>
///
/// **SPDX-License-Identifier**: MIT
///
/// See LICENSE for details.
#[derive(Debug)]
pub struct Shell {
    /// Enable debug mode
    debug: bool,
    /// Shell start time
    start: Option<std::time::Instant>,
    /// Shell uptime
    uptime: fn(start: std::time::Instant) -> Option<std::time::Duration>,
    /// Shell defaults
    defaults: crate::config::Defaults,

    thememanager: crate::style::ThemeManager,
    // pub args: Option<crate::types::Arguments>,
    // pub config: Option<crate::types::Config>,
    pub config: Option<std::sync::Arc<std::sync::Mutex<crate::config::Config>>>,
    pub args: Option<std::sync::Arc<std::sync::Mutex<crate::config::Arguments>>>,
    pub interpreter: crate::lang::Interpreter,
    pub context: crate::context::Context,
    pub pid: Option<u32>,
    pub paused: bool,
    pub running: bool,
    // replace events with history manager
    history: std::sync::Arc<std::sync::Mutex<crate::history::History>>,
    events: std::sync::Arc<std::sync::Mutex<Vec<crate::history::Event>>>,
    env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    tokens: Vec<Vec<crate::tokens::Token>>,
    expressions: Vec<crate::expressions::Expressions>,

    // TODO: store watchers in a HashMap
    /// config file watcher
    config_watcher: Option<notify::RecommendedWatcher>,
    /// receiver for config file change signals
    config_receiver: Option<std::sync::mpsc::Receiver<crate::config::ConfigSignal>>,
    /// sender for config file change signals
    config_sender: Option<std::sync::mpsc::Sender<crate::config::ConfigSignal>>,
}

impl Shell {
    /// Handle configuration signals
    fn handle_config_signals(&mut self) {
        if let Some(receiver) = &self.config_receiver {
            while let Ok(signal) = receiver.try_recv() {
                match signal {
                    crate::config::ConfigSignal::Reloaded(cfg) => {
                        if self.debug {
                            println!("🔄 reloading configuration due to file change");
                        }
                        let args = self
                            .args
                            .as_ref()
                            .and_then(|a| Some(a.lock().unwrap().clone()));
                        let new_config = Self::configure(args.as_ref().map(|a| a.clone()));
                        if let Some(cfg) = &self.config {
                            let mut cfg_lock = cfg.lock().unwrap();
                            *cfg_lock = new_config;
                        }
                    }
                    _ => {
                        if self.debug {
                            println!("⚠️ received unhandled config signal: {:?}", signal);
                        }
                    }
                }
            }
        }
    }

    /// Create a new Rustyline editor instance
    // TODO: investigate using a custom editor config
    fn create_reader(&self) -> rustyline::DefaultEditor {
        let config = rustyline::config::Config::builder()
            .edit_mode(rustyline::config::EditMode::Vi)
            .build();
        let rl = rustyline::DefaultEditor::with_config(config);
        rl.unwrap()
    }

    /// Get elapsed time since shell start
    fn elapsed(&self) -> Option<std::time::Duration> {
        if let Some(start) = self.start {
            Some(start.elapsed())
        } else {
            None
        }
    }

    /// Configure the shell
    fn configure(args: Option<crate::config::Arguments>) -> crate::config::Config {
        let defaults = crate::config::Defaults::default();
        let config_path = args
            .as_ref()
            .and_then(|args| args.config_path.as_ref())
            .unwrap_or(&defaults.config_path)
            .clone();

        let config = crate::config::Config::resolve(config_path.as_str(), &args);
        config.unwrap()
    }

    pub fn new(args: crate::config::Arguments) -> Self {
        // capture user environment
        let user_environment =
            std::env::vars().collect::<std::collections::HashMap<String, String>>();
        // load defaults
        let defaults = crate::config::Defaults::default();

        // capture command line args
        let args = Some(args);

        let env_config = crate::config::Environment::new(args.as_ref().unwrap().clone());

        // Determine history path - from args or defaults
        // TODO: incorporate TURTLE_HISTORY_PATH env var
        let history_path = args
            .as_ref()
            .and_then(|args| args.history_path.as_ref())
            .unwrap_or(&defaults.history_path)
            .clone();

        // Determine config path - from args or defaults
        // TODO: incorporate TURTLE_CONFIG_PATH env var, or  XDG_CONFIG_HOME convention
        let config_path = args
            .as_ref()
            .and_then(|args| args.config_path.as_ref())
            .unwrap_or(&defaults.config_path)
            .clone();

        // load config from file or use default config blob
        let config = Self::configure(args.as_ref().map(|a| a.clone()));

        let config = Some(std::sync::Arc::new(std::sync::Mutex::new(config)));

        let debug = args.as_ref().unwrap().debug
            || config
                .as_ref()
                .map(|c| c.lock().unwrap().debug)
                .unwrap_or(false)
            || defaults.debug;

        let mut _aliases_ = std::collections::HashMap::new();

        if let Some(cfg) = &config {
            if let Some(turtle_aliases) = &cfg.lock().unwrap().aliases {
                for (key, value) in turtle_aliases {
                    _aliases_.insert(key.clone(), value.clone());
                }
            }
        }

        let aliases = std::sync::Arc::new(std::sync::Mutex::new(_aliases_));
        let user_env = crate::utils::build_user_environment();
        let env = std::sync::Arc::new(std::sync::Mutex::new(user_env));
        let vars = std::sync::Arc::new(std::sync::Mutex::new(std::collections::HashMap::<
            String,
            crate::expressions::Expressions,
        >::new()));

        let args = Some(std::sync::Arc::new(std::sync::Mutex::new(args.unwrap())));

        let history_path = args
            .as_ref()
            .and_then(|args| args.lock().unwrap().history_path.clone())
            .unwrap_or(defaults.history_path.clone());

        let mut history = crate::history::History::new(
            Some(history_path.clone()),
            Some(defaults.save_interval),
            debug,
        );

        history.setup();
        let history = std::sync::Arc::new(std::sync::Mutex::new(history));

        let events = history.lock().unwrap().load().unwrap();
        let events = std::sync::Arc::new(std::sync::Mutex::new(events));

        let mut context = crate::context::Context::new(
            env.clone(),
            aliases.clone(),
            vars.clone(),
            events.clone(),
            debug,
        );
        context.setup();
        let mut builtin_names: Vec<String> = Vec::new();
        if let Some(builtins) = &context.builtins {
            let names = builtins.list();
            builtin_names.extend(names);
        }

        let interpreter = crate::lang::Interpreter::new(
            env.clone(),
            aliases.clone(),
            vars.clone(),
            builtin_names.clone(),
            debug,
        );

        // let thememanager = crate::style::ThemeManager::new();
        let thememanager = crate::style::ThemeManager::from(crate::style::DEFAULT_THEMES);

        if debug {
            println!("🐢 initializing TurtleShell");
        }
        let (signal_sender, signal_receiver) =
            std::sync::mpsc::channel::<crate::config::ConfigSignal>();

        Shell {
            debug,
            start: None,
            uptime: |start: std::time::Instant| -> Option<std::time::Duration> {
                Some(start.elapsed())
            },
            pid: None,
            paused: false,
            running: false,
            defaults,
            config_watcher: None,
            config: config.clone(),
            args,
            thememanager,
            history,
            events,
            env,
            aliases,
            interpreter,
            context,
            tokens: Vec::new(),
            expressions: Vec::new(),
            config_receiver: Some(signal_receiver),
            config_sender: Some(signal_sender),
        }
    }

    /// Set up the shell
    fn setup(&mut self) -> std::collections::HashMap<String, u128> {
        let start = crate::utils::now();
        self.pid = std::process::id().into();
        self.running = true;
        self.paused = false;
        let elapsed = start.elapsed();
        if self.debug {
            println!("🐢 setup completed in {} milliseconds", elapsed.as_millis());
        }
        return std::collections::HashMap::from([("total".into(), elapsed.as_millis())]);
    }

    /// Start the shell main loop
    pub fn start(&mut self) {
        //
        // record start time
        self.start = Some(std::time::Instant::now());

        // setup the shell
        self.setup();

        // get default paths and values
        let default_config_path = self.defaults.config_path.clone();
        let default_history_path = self.defaults.history_path.clone();
        let default_prompt = self.defaults.prompt.clone();
        let default_theme = self.defaults.theme.clone();

        // lock & process args and config
        let args = self
            .args
            .as_ref()
            .and_then(|a| Some(a.lock().unwrap().clone()));

        let c_args = args.clone();

        let config = self
            .config
            .as_ref()
            .and_then(|c| Some(c.lock().unwrap().clone()));

        let c_config = config.clone();

        // --version flag
        if let Some(show_version) = args.as_ref().and_then(|a| Some(a.version)) {
            if show_version {
                println!("version: {}", crate::constants::VERSION);
                std::process::exit(0);
            }
        }

        // handle: --display-env flag
        let user_env = crate::config::Environment::new(args.as_ref().unwrap().clone());
        if let Some(display_env) = args.as_ref().and_then(|a| Some(a.display_env)) {
            if display_env {
                for (key, value) in user_env.config.iter() {
                    {
                        println!("{}={}", key, value);
                    }
                }
                std::process::exit(0);
            }
        }

        // handle: --display-defaults flag
        if let Some(display_defaults) = args.as_ref().and_then(|a| Some(a.display_defaults)) {
            if display_defaults {
                let defaults = crate::config::Defaults::default();
                println!("{}", defaults.to_string());
                std::process::exit(0);
            }
        }

        // handle: --display-config flag
        if let Some(display_config) = args.as_ref().and_then(|a| Some(a.display_config)) {
            if display_config {
                if let Some(cfg) = &self.config {
                    let cfg = cfg.lock().unwrap();
                    let resolved = crate::config::ResolvedConfig::from(cfg.clone());
                    println!("{}", resolved.to_string());
                    std::process::exit(0);
                } else {
                    eprintln!("❌ no configuration loaded");
                    std::process::exit(1);
                }
            }
        }

        // handle: --list-themes flag
        if let Some(list_themes) = self
            .args
            .as_ref()
            .and_then(|a| Some(a.lock().unwrap().available_themes))
        {
            if list_themes {
                self.thememanager.list().iter().for_each(|theme_name| {
                    println!("- {}", theme_name);
                });
                std::process::exit(0);
            }
        }

        // handle: --watch-config flag
        if let Some(watch_config) = args.as_ref().and_then(|a| Some(a.watch_config)) {
            let config_path = args
                // .as_ref()
                .and_then(|args| args.config_path)
                .unwrap_or(default_config_path.clone());
            if watch_config {
                if let Some(cfg) = &self.config {
                    let cfg = cfg.lock().unwrap();
                    match cfg.clone().watch(
                        config_path.as_str(),
                        c_args,
                        self.config_sender.clone(),
                    ) {
                        Ok(watcher) => {
                            self.config_watcher = Some(watcher);
                            if self.debug {
                                println!("✅ watching config file for changes: {}", config_path);
                            }
                        }
                        Err(e) => {
                            eprintln!("❌ failed to watch config file: {}", e);
                        }
                    }
                } else {
                    eprintln!(
                        "❌ cannot watch config file because it failed to load: {}",
                        config_path
                    );
                }
            }
        }

        /*
            get prompt from the configuration file, or use the default
        */
        let user_prompt = config
            .clone()
            .and_then(|cfg| cfg.prompt)
            .unwrap_or(default_prompt.clone());

        /*
            get theme from the configuration file, or use the default
        */
        let user_theme = config
            .clone()
            .and_then(|cfg| cfg.theme)
            .unwrap_or(default_theme.clone());

        let start = crate::utils::now();
        let mut editor = self.create_reader();

        self.thememanager
            .apply(&mut std::io::stdout(), &user_theme)
            .ok();

        // get our prompt from the configuration file, or use the default
        let user_prompt = self
            .config
            .as_ref()
            .and_then(|cfg| cfg.lock().unwrap().prompt.clone())
            .unwrap_or(default_prompt.clone());

        let rendered_prompt = user_prompt.clone();
        let mut turtle_prompt = crate::style::Prompt::new(rendered_prompt.as_str());

        if let Some(command) = self
            .args
            .as_ref()
            .and_then(|args| args.lock().unwrap().command.clone())
        // .as_str()
        {
            let tokens = self.interpreter.tokenize(command.as_str());

            let expr = self.interpreter.interpret();
            let result = self.context.eval(expr.clone());
            if let Some(res) = result {
                // res.
                if self.debug {
                    println!("result: {:?}", res);
                }
                // if result.
                std::process::exit(0);
            }
            // exit after executing the command from args
        }

        // if self.con
        // main shell loop
        loop {
            // handle any config file change signals
            self.handle_config_signals();

            let readline = editor.readline(turtle_prompt.render().as_str());

            // get user input
            let input = match readline {
                Ok(line) => line,
                Err(rustyline::error::ReadlineError::Interrupted) => {
                    println!("^C");
                    continue;
                }
                Err(rustyline::error::ReadlineError::Eof) => {
                    println!("^D");
                    std::process::exit(0);
                    // exit the shell on EOF
                }
                Err(err) => {
                    println!("input error: {:?}", err);
                    break;
                }
            };

            // trim input
            let input = input.trim();

            // skip empty input
            if input.is_empty() {
                continue;
            }

            let tokens = self.interpreter.tokenize(input);
            if self.debug {
                println!("tokens: {:?}", tokens);
            }
            self.tokens.push(tokens.clone());
            let expr = self.interpreter.interpret();

            if self.debug {
                println!("expression: {:?}", expr);
            }

            if expr.is_none() {
                println!("Invalid command or expression");
                continue;
            }

            self.expressions.push(expr.clone().unwrap());
            let result = self.context.eval(expr.clone());
            if let Some(res) = result {
                if self.debug {
                    println!("result: {:?}", res);
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

pub enum ShellError {
    /// Generic shell error
    GenericError(String),
    /// Command not found error
    CommandNotFound(String),
    /// Execution error
    ExecutionError(String),
}

impl std::fmt::Display for ShellError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ShellError::GenericError(msg) => write!(f, "Shell Error: {}", msg),
            ShellError::CommandNotFound(cmd) => write!(f, "Command Not Found: {}", cmd),
            ShellError::ExecutionError(msg) => write!(f, "Execution Error: {}", msg),
        }
    }
}

pub enum ShellSignal {
    //// Signal to exit the shell
    ExitShell,
    /// Signal to terminate the shell
    TerminateShell,
    /// Signal to pause the shell
    PauseShell,
    /// Signal to resume the shell
    ResumeShell,
}
