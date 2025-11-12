// #[derive(Debug)]
// pub struct Shell {
//     debug: bool,
//     defaults: crate::types::Defaults,
//     watcher: Option<notify::RecommendedWatcher>,
//     thememanager: crate::types::ThemeManager,
//     pub args: Option<crate::types::Arguments>,
//     pub config: Option<crate::types::Config>,
//     pub interpreter: crate::types::Interpreter,
//     pub context: crate::types::Context,
//     pub pid: Option<u32>,
//     // pub uptime: Option<u64>,
//     pub paused: bool,
//     pub running: bool,
//     history: std::sync::Arc<std::sync::Mutex<Vec<crate::types::HistoryEvent>>>,
//     env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
//     aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
//     tokens: Vec<Vec<crate::types::Token>>,
//     expressions: Vec<crate::types::Expressions>,
// }

// impl Shell {
//     fn get_readline(&self) -> rustyline::DefaultEditor {
//         let config = rustyline::config::Config::builder()
//             .edit_mode(rustyline::config::EditMode::Vi)
//             .build();
//         let rl = rustyline::DefaultEditor::with_config(config);
//         rl.unwrap()
//     }

//     pub fn new(args: crate::types::Arguments) -> Self {
//         let defaults = crate::types::Defaults::default();
//         let args = Some(args);

//         let config_path = args
//             .as_ref()
//             .and_then(|args| args.config_path.as_ref())
//             .unwrap_or(&defaults.config_path);

//         // let config = crate::configuration::load_config_from_path(config_path);
//         let config = crate::types::Config::load(config_path);

//         let mut _aliases_ = std::collections::HashMap::new();
//         if let Some(cfg) = &config {
//             if let Some(turtle_aliases) = &cfg.aliases {
//                 for (key, value) in turtle_aliases {
//                     _aliases_.insert(key.clone(), value.clone());
//                 }
//             }
//         }

//         let debug = args.as_ref().unwrap().debug
//             || config.as_ref().map(|c| c.debug).unwrap_or(false)
//             || defaults.debug;

//         let aliases = std::sync::Arc::new(std::sync::Mutex::new(_aliases_));
//         let user_env = crate::utils::build_user_environment();
//         let env = std::sync::Arc::new(std::sync::Mutex::new(user_env));
//         let vars = std::sync::Arc::new(std::sync::Mutex::new(std::collections::HashMap::<
//             String,
//             crate::types::Expressions,
//         >::new()));

//         let history_path = args
//             .as_ref()
//             .and_then(|args| args.history_path.as_ref())
//             .unwrap_or(&defaults.history_path);

//         let history =
//             crate::history::load_history_from_path(history_path.as_str()).unwrap_or_default();

//         let history = std::sync::Arc::new(std::sync::Mutex::new(history));

//         let mut context =
//             crate::types::Context::new(env.clone(), aliases.clone(), vars.clone(), history.clone());
//         context.setup();
//         let mut builtin_names: Vec<String> = Vec::new();
//         if let Some(builtins) = &context.builtins {
//             let names = builtins.list();
//             builtin_names.extend(names);
//         }

//         let interpreter = crate::types::Interpreter::new(
//             env.clone(),
//             aliases.clone(),
//             vars.clone(),
//             builtin_names.clone(),
//         );

//         if debug {
//             println!(
//                 "🐢 Initializing TurtleShell with config: {:?} and args {:?}",
//                 config, args
//             );
//         }

//         let thememanager = crate::types::ThemeManager::new();

//         Shell {
//             debug,
//             defaults,
//             watcher: None,
//             config: config.clone(),
//             args,
//             thememanager,
//             history,
//             env,
//             aliases,
//             interpreter,
//             context,
//             pid: None,
//             paused: false,
//             running: true,
//             tokens: Vec::new(),
//             expressions: Vec::new(),
//         }
//     }

//     /// Set up the shell
//     pub fn setup(&mut self) -> std::collections::HashMap<String, u128> {
//         let _start = crate::utils::this_instant();
//         self.pid = std::process::id().into();
//         self.running = true;
//         self.paused = false;
//         let _elapsed = _start.elapsed();
//         if self.debug {
//             println!(
//                 "🐢 setup completed in {} milliseconds",
//                 _elapsed.as_millis()
//             );
//         }
//         return std::collections::HashMap::from([("total".into(), _elapsed.as_millis())]);
//     }

//     // Reload the shell configuration
//     // pub fn reload(&mut self) -> crate::types::Config {
//     //     self.load_config()
//     // }

//     /// Start the shell main loop
//     pub fn start(&mut self) {
//         self.setup();

//         // Set up config file watcher if enabled
//         // this is not working
//         if let Some(watch_config) = self.args.as_ref().and_then(|a| Some(a.watch_config)) {
//             let config_path = self
//                 .args
//                 .as_ref()
//                 .and_then(|args| args.config_path.as_ref())
//                 .unwrap_or(&self.defaults.config_path);
//             if watch_config {
//                 if let Some(cfg) = &self.config {
//                     match cfg.watch(config_path.as_str()) {
//                         Ok(watcher) => {
//                             self.watcher = Some(watcher);
//                             if self.debug {
//                                 println!("✅ watching config file for changes: {}", config_path);
//                             }
//                         }
//                         Err(e) => {
//                             eprintln!("❌ failed to watch config file: {}", e);
//                         }
//                     }
//                 } else {
//                     eprintln!(
//                         "❌ cannot watch config file because it failed to load: {}",
//                         config_path
//                     );
//                 }
//             }
//         }

//         let start = crate::utils::this_instant();
//         let mut editor = self.get_readline();
//         let default_prompt = crate::types::Defaults::default().prompt;
//         let default_theme = crate::types::Defaults::default().theme;

//         if let Some(list_themes) = self.args.as_ref().and_then(|a| Some(a.list_themes)) {
//             if list_themes {
//                 println!("Available Themes:");
//                 self.thememanager.list().iter().for_each(|theme_name| {
//                     println!("- {}", theme_name);
//                 });
//                 std::process::exit(0);
//             }
//         }

//         self.thememanager
//             .apply(&mut std::io::stdout(), &default_theme)
//             .ok();

//         // get our prompt from the configuration file, or use the default
//         let user_prompt = self
//             .config
//             .as_ref()
//             .and_then(|cfg| cfg.prompt.as_ref())
//             .unwrap_or(&default_prompt);

//         let rendered_prompt = user_prompt.clone();
//         let mut turtle_prompt = crate::types::Prompt::new(rendered_prompt.as_str());

//         if let Some(command) = self.args.as_ref().and_then(|args| args.command.as_ref()) {
//             let tokens = self.interpreter.tokenize(command);

//             let expr = self.interpreter.interpret();
//             let result = self.context.eval(expr.clone());
//             if let Some(res) = result {
//                 // res.
//                 if self.debug {
//                     println!("Result: {:?}", res);
//                 }
//                 // if result.
//                 std::process::exit(0);
//             }
//             // exit after executing the command from args
//         }

//         loop {
//             let readline = editor.readline(turtle_prompt.render().as_str());

//             // get user input
//             let input = match readline {
//                 Ok(line) => line,
//                 Err(rustyline::error::ReadlineError::Interrupted) => {
//                     println!("^C");
//                     continue;
//                 }
//                 Err(rustyline::error::ReadlineError::Eof) => {
//                     println!("^D");
//                     std::process::exit(0);
//                     // exit the shell on EOF
//                 }
//                 Err(err) => {
//                     println!("Error: {:?}", err);
//                     break;
//                 }
//             };

//             // trim input
//             let input = input.trim();

//             // skip empty input
//             if input.is_empty() {
//                 continue;
//             }

//             let tokens = self.interpreter.tokenize(input);
//             if self.debug {
//                 println!("Tokens: {:?}", tokens);
//             }
//             self.tokens.push(tokens.clone());
//             let expr = self.interpreter.interpret();

//             if self.debug {
//                 println!("Expression: {:?}", expr);
//             }

//             if expr.is_none() {
//                 println!("Invalid command or expression");
//                 continue;
//             }

//             self.expressions.push(expr.clone().unwrap());
//             let result = self.context.eval(expr.clone());
//             if let Some(res) = result {
//                 if self.debug {
//                     println!("Result: {:?}", res);
//                 }
//             }
//         }
//         let elapsed = start.elapsed();
//         if self.debug {
//             println!(
//                 "🐢 shell main loop exited after {} milliseconds",
//                 elapsed.as_millis()
//             );
//         }
//     }
// }
