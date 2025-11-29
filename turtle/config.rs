use notify::Watcher;
use serde::{Deserialize, Serialize};

/// default interval for worker threads
pub const DEFAULT_INTERVAL_SECS: u64 = 60;

/// default prompt template
pub const DEFAULT_PROMPT: &str = "<+ 🐢 +> ";

/// default continuation prompt template
pub const DEFAULT_CONTINUATION_PROMPT: &str = "⏭️ ";

/// default format
pub const DEFAULT_FORMAT: &str = "table";

/// default error prompt template
pub const DEFAULT_ERROR_PROMPT: &str = "<<< ❌❌❌ >>>";

/// default history size
pub const DEFAULT_HISTORY_SIZE: usize = 1000;

/// default theme
pub const DEFAULT_THEME: &str = "monokai";

/// default debug
pub const DEFAULT_DEBUG: bool = false;

/// default config
pub const DEFAULT_CONFIG: &str = r#"
# Default Turtle configuration file
debug: false
prompt: "<+ 🐢 +> "
continuation_prompt: "⏭️ "
error_prompt: "<<< ❌❌❌ >>>"
history_size: 1000
theme: "monokai"
"#;

/// default environment variables (WIP)
pub static DEFAULT_ENVIRONMENT_CONFIG: once_cell::sync::Lazy<
    std::collections::HashMap<&'static str, &'static str>,
> = once_cell::sync::Lazy::new(|| {
    let mut m = std::collections::HashMap::new();
    m.insert("TURTLE_CONFIG_PATH", "~/.turtlerc.yaml");
    m.insert("TURTLE_HISTORY_PATH", "~/.turtle_history.json");
    m.insert("TURTLE_PROMPT", "<+ 🐢 +> ");
    m.insert("TURTLE_CONTINUATION_PROMPT", "⏭️ ");
    m.insert("TURTLE_ERROR_PROMPT", "<<< ❌❌❌ >>>");
    m.insert("TURTLE_HISTORY_SIZE", "1000");
    m.insert("TURTLE_THEME", "monokai");
    m
});

/// sane defaults for the turtle shell
///
/// used when no config file or environment variables are set
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Defaults {
    pub config: String,
    pub config_path: String,
    pub history_path: String,
    pub prompt: String,
    pub continuation_prompt: String,
    pub error_prompt: String,
    pub history_size: usize,
    pub theme: String,
    pub debug: bool,
    pub save_interval: u64,
    pub format: String,
}

impl Default for Defaults {
    fn default() -> Self {
        let home = dirs::home_dir().unwrap_or_else(|| std::path::PathBuf::from("."));
        let config_path = home.join(".turtlerc.yaml");
        let history_path = home.join(".turtle_history.json");
        Defaults {
            config: DEFAULT_CONFIG.to_string(),
            config_path: config_path.to_string_lossy().to_string(),
            history_path: history_path.to_string_lossy().to_string(),
            prompt: DEFAULT_PROMPT.to_string(),
            continuation_prompt: DEFAULT_CONTINUATION_PROMPT.to_string(),
            error_prompt: DEFAULT_ERROR_PROMPT.to_string(),
            history_size: DEFAULT_HISTORY_SIZE,
            theme: DEFAULT_THEME.to_string(),
            debug: DEFAULT_DEBUG,
            save_interval: DEFAULT_INTERVAL_SECS,
            format: DEFAULT_FORMAT.to_string(),
        }
    }
}

impl std::fmt::Display for Defaults {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "Defaults {{ config_path: {}, history_path: {}, prompt: {}, continuation_prompt: {}, error_prompt: {}, history_size: {}, theme: {}, debug: {}, save_interval: {}, format: {} }}",
            self.config_path,
            self.history_path,
            self.prompt,
            self.continuation_prompt,
            self.error_prompt,
            self.history_size,
            self.theme,
            self.debug,
            self.save_interval,
            self.format
        )
    }
}

/// shell environment variables
///
/// used to override config file settings
///
/// setting the environment variables `TURTLE_PROMPT` will override the prompt setting in the config file
#[derive(Debug, Clone)]
pub struct Environment {
    pub _debug: bool,
    pub config: std::collections::HashMap<String, String>,
    pub _defaults: bool, // pub config: std::collections::HashMap<String, String>,
}

impl Environment {
    pub fn new(args: crate::config::Arguments) -> Self {
        let debug = args.debug;

        let mut config: std::collections::HashMap<String, String> =
            std::collections::HashMap::new();
        for (key, value) in std::env::vars() {
            if key.starts_with("TURTLE_") {
                if debug {
                    println!("using config var variable: {}={}", key, value);
                }
                let var_name = key.trim_start_matches("TURTLE_").to_string();
                config.insert(var_name, value);
            }
        }
        if config.is_empty() {
            Environment::default()
        } else {
            Environment {
                _debug: debug,
                config,
                _defaults: true,
            }
        }
    }

    pub fn _set(&mut self, key: &str, value: &str) {
        self.config.insert(key.to_string(), value.to_string());
    }

    pub fn _unset(&mut self, key: &str) {
        self.config.remove(key);
    }

    pub fn get(&self, key: &str) -> Option<&String> {
        self.config.get(key)
    }

    pub fn _list(&self) -> Vec<(&String, &String)> {
        self.config.iter().collect()
    }
}

impl Default for Environment {
    fn default() -> Self {
        let mut config: std::collections::HashMap<String, String> =
            std::collections::HashMap::new();

        for (key, value) in DEFAULT_ENVIRONMENT_CONFIG.iter() {
            config.insert(key.to_string(), value.to_string());
        }
        Environment {
            config,
            _defaults: true,
            _debug: false,
        }
    }
}

/// shell configuration
///
/// loaded from a YAML file or YAML string
///
/// ```yaml
/// debug: true
/// prompt: "<+ 🐢 +> "
/// aliases:
///  ll: "ls -la"
/// history_size: 2000
/// theme: "monokai"
/// ```
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    /// enable debugging
    ///
    /// default: false
    ///
    ///  command line: --debug
    ///
    /// `TURTLE_DEBUG=true`
    ///
    /// TODO: make this an Option<bool> to distinguish between unset and false
    // pub debug: bool,
    /// command prompt template
    ///
    ///
    /// default: "<+ 🐢 +> "
    ///
    /// environment `TURTLE_PROMPT="<+ 🐢 +> "`
    pub prompt: Option<String>,
    /// command aliases
    ///
    /// default: none
    ///
    /// environment `TURTLE_ALIASES='{"ll": "ls -la"}'`
    pub aliases: Option<std::collections::HashMap<String, String>>,
    /// command history size
    ///
    /// default: 1000
    ///
    /// environment `TURTLE_HISTORY_SIZE=1000`
    pub history_size: Option<usize>,
    /// color theme
    ///
    /// default: "monokai"
    ///
    /// environment `TURTLE_THEME="monokai"`
    pub theme: Option<String>,
}

impl Default for Config {
    fn default() -> Self {
        let defaults = Defaults::default();
        Config {
            prompt: Some(defaults.prompt),
            aliases: None,
            history_size: Some(defaults.history_size),
            theme: Some(defaults.theme),
        }
    }
}

impl std::fmt::Display for Config {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "Config prompt: {:?}, aliases: {:?}, history_size: {:?}, theme: {:?} }}",
            self.prompt, self.aliases, self.history_size, self.theme
        )
    }
}

impl Config {
    /// Return a list of fields in the Config struct
    fn fields() -> Vec<String> {
        let json = serde_json::to_value(Config::default()).unwrap_or_default();
        json.as_object()
            .unwrap()
            .keys()
            .cloned()
            .collect::<Vec<String>>()
    }

    /// create a new Config from a yaml file path or yaml content string
    pub fn new(yaml: &str, args: Option<crate::config::Arguments>) -> Option<Self> {
        Self::load(
            yaml,
            args.as_ref()
                .unwrap_or(&crate::config::Arguments::default()),
        )
        .or_else(|| {
            Self::loads(
                yaml,
                args.as_ref()
                    .unwrap_or(&crate::config::Arguments::default()),
            )
        })
        // or else return the default config
        .or_else(|| Some(Config::default()))
    }

    /// resolve configuration
    ///
    /// resolves a Config using the following rules:
    ///
    /// 1. start with the provided Config or default Config
    ///
    /// 2. override with environment variables if set
    ///
    /// 3. override with command line arguments if set and where applicable
    ///
    pub fn resolve(
        // &self,
        // config: &Config,
        yaml: &str,
        // env: &Environment,
        args: &Option<crate::config::Arguments>,
    ) -> Option<Self> {
        let defaults = Defaults::default();
        let config = Config::new(yaml, args.clone())?;
        let env = Environment::new(args.clone().unwrap_or_default());
        let mut merged = config.clone();

        /*
        - override with environment variables / args
        - fall back to defaults if not set
        */

        for field in Config::fields() {
            let env_key = format!("TURTLE_{}", field.to_uppercase());
            if let Some(value) = env.get(&env_key) {
                match field.as_str() {
                    "prompt" => {
                        merged.prompt = Some(value.clone());
                    }
                    "aliases" => {
                        if let Ok(aliases_map) =
                            serde_json::from_str::<std::collections::HashMap<String, String>>(value)
                        {
                            merged.aliases = Some(aliases_map);
                        }
                    }
                    "history_size" => {
                        if let Ok(size) = value.parse::<usize>() {
                            merged.history_size = Some(size);
                        }
                    }
                    "theme" => {
                        merged.theme = Some(value.clone());
                    }
                    _ => {}
                }
            }

            // if the value in merged is None, set to default
            match field.as_str() {
                "prompt" => {
                    if merged.prompt.is_none() {
                        merged.prompt = Some(defaults.prompt.clone());
                    }
                }
                "aliases" => {
                    if merged.aliases.is_none() {
                        merged.aliases = Some(std::collections::HashMap::new());
                    }
                }
                "history_size" => {
                    if merged.history_size.is_none() {
                        merged.history_size = Some(defaults.history_size);
                    }
                }
                "theme" => {
                    if merged.theme.is_none() {
                        merged.theme = Some(defaults.theme.clone());
                    }
                }
                _ => {}
            }
        }

        if let Some(prompt) = env.get("PROMPT") {
            merged.prompt = Some(prompt.clone());
        }
        if let Some(history_size) = env.get("HISTORY_SIZE") {
            if let Ok(size) = history_size.parse::<usize>() {
                merged.history_size = Some(size);
            }
        }
        if let Some(theme) = env.get("THEME") {
            merged.theme = Some(theme.clone());
        }

        Some(merged)
    }

    pub fn _as_mutex(&self) -> std::sync::Arc<std::sync::Mutex<Self>> {
        std::sync::Arc::new(std::sync::Mutex::new(self.clone()))
    }

    pub fn load(path: &str, args: &crate::config::Arguments) -> Option<Self> {
        let expanded_path = if path.starts_with("~") {
            if let Some(home) = dirs::home_dir() {
                let without_tilde = path.trim_start_matches("~");
                home.join(without_tilde).to_string_lossy().to_string()
            } else {
                path.to_string()
            }
        } else {
            path.to_string()
        };

        let contents = match std::fs::read_to_string(&expanded_path) {
            Ok(c) => c,
            Err(e) => {
                if args.debug {
                    println!("❌ Failed to read config file at {}: {}", expanded_path, e);
                }
                return None;
            }
        };
        let config = match serde_yaml::from_str::<Config>(&contents) {
            Ok(c) => c,
            Err(e) => {
                if args.debug {
                    println!("❌ Failed to parse config file at {}: {}", expanded_path, e);
                }
                return None;
            }
        };

        if args.debug {
            println!("✅ loaded config file at {}", expanded_path);
        }

        Some(config)
    }

    pub fn loads(yaml_content: &str, args: &crate::config::Arguments) -> Option<Self> {
        let config = match serde_yaml::from_str::<Config>(yaml_content) {
            Ok(c) => c,
            Err(e) => {
                if args.debug {
                    println!("❌ Failed to parse config content: {}", e);
                }
                return None;
            }
        };
        if args.debug {
            println!("✅ loaded config from string content");
        }
        Some(config)
    }

    pub fn watch(
        self,
        path: &str,
        args: Option<crate::config::Arguments>,
        config_sender: Option<std::sync::mpsc::Sender<crate::config::ConfigSignal>>,
    ) -> std::io::Result<notify::RecommendedWatcher> {
        let watch_path = crate::utils::expand_path(path);
        let (tx, rx) = std::sync::mpsc::channel();
        let mut watcher = notify::recommended_watcher(tx)
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e))?;

        watcher
            .watch(
                std::path::Path::new(&watch_path),
                notify::RecursiveMode::NonRecursive,
            )
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e))?;

        let _current_config = self.clone();
        std::thread::spawn(move || {
            for res in rx {
                match res {
                    Ok(event) => {
                        let config_updated = event.kind.is_modify()
                            && matches!(
                                event.kind,
                                notify::EventKind::Modify(notify::event::ModifyKind::Data(_))
                            );

                        if config_updated {
                            let new_config = Config::load(
                                &watch_path,
                                args.as_ref()
                                    .unwrap_or(&crate::config::Arguments::default()),
                            );

                            match new_config {
                                Some(cfg) => {
                                    if let Some(sender) = &config_sender {
                                        let _ =
                                            sender.send(crate::config::ConfigSignal::Reloaded(cfg));
                                    }
                                }
                                None => {
                                    if let Some(sender) = &config_sender {
                                        let _ = sender.send(crate::config::ConfigSignal::Error(
                                            format!("Failed to reload config from {}", watch_path),
                                        ));
                                    }
                                }
                            }
                        }
                    }
                    Err(e) => println!("watch error: {:?}", e),
                }
            }
        });

        Ok(watcher)
    }

    pub fn _write(&self, path: &str) -> std::io::Result<()> {
        let expanded_path = if path.starts_with("~") {
            if let Some(home) = dirs::home_dir() {
                let without_tilde = path.trim_start_matches("~");
                home.join(without_tilde).to_string_lossy().to_string()
            } else {
                path.to_string()
            }
        } else {
            path.to_string()
        };
        let yaml = serde_yaml::to_string(self).unwrap();
        std::fs::write(expanded_path, yaml)
    }

    pub fn _validate(&self) -> bool {
        true
    }

    pub fn _to_json(&self) -> Option<String> {
        serde_json::to_string_pretty(self).ok()
    }
}

#[derive(Debug, Clone)]
pub enum ConfigSignal {
    _Loaded(Config),
    Reloaded(Config),
    Error(String),
}

/// resolved shell configuration
///
/// used internally by the shell after merging config file, environment variables, and command line arguments
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ResolvedConfig {
    // pub debug: bool,
    pub prompt: String,
    pub aliases: std::collections::HashMap<String, String>,
    pub history_size: usize,
    pub theme: String,
}

impl std::fmt::Display for ResolvedConfig {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "ResolvedConfig {{ prompt: {}, aliases: {:?}, history_size: {}, theme: {} }}",
            self.prompt, self.aliases, self.history_size, self.theme
        )
    }
}

impl From<Config> for ResolvedConfig {
    fn from(config: Config) -> Self {
        let defaults = Defaults::default();
        ResolvedConfig {
            prompt: config.prompt.unwrap_or(defaults.prompt),
            aliases: config.aliases.unwrap_or_default(),
            history_size: config.history_size.unwrap_or(defaults.history_size),
            theme: config.theme.unwrap_or(defaults.theme),
        }
    }
}

/// command line arguments
///
/// control shell behavior and override config file values
#[derive(clap::Parser, Clone, Default, Debug, Serialize, Deserialize)] // NOTE: temporarily removed the Default trait to define out own
#[command(name = "turtle", about = "An interpreted Rust shell")]
pub struct Arguments {
    // /// show version
    // #[arg(short, long, help = "Show Version", default_value_t = false)]
    // pub version: bool,
    /// enable debugging
    #[arg(short, long, help = "Enable Debugging", default_value_t = false)]
    pub debug: bool,

    /// enable debugging
    #[arg(long, help = "Enable Expression Debugging", default_value_t = false)]
    pub debug_expressions: bool,

    /// enable debugging
    #[arg(long, help = "Enable Tokenization Debugging", default_value_t = false)]
    pub debug_tokenization: bool,

    /// debug context
    #[arg(long, help = "Enable Context Debugging", default_value_t = false)]
    pub debug_context: bool,

    /// show version and exit
    #[arg(short, long, help = "Show Version and Exit", default_value_t = false)]
    pub version: bool,

    /// configuration file
    #[arg(long, help = "Config File", default_value = "~/.turtle.yaml")]
    pub config_path: Option<String>,

    /// history file
    #[arg(long, help = "History File", default_value = "~/.turtle_history.json")]
    pub history_path: Option<String>,

    /// command to execute in non-interactive mode
    #[arg(long, help = "Evaluate Command", default_value = None)]
    pub command: Option<String>,

    /// set output format
    #[arg(short, long, help = "Output Format", default_value = "table")]
    pub format: Option<String>,

    /// skip history loading
    #[arg(long, help = "Skip History", default_value_t = false)]
    pub skip_history: bool,

    // skip alias loading
    #[arg(long, help = "Skip Aliases", default_value_t = false)]
    pub skip_aliases: bool,

    /// list available themes
    #[arg(long, help = "List Available Themes", default_value_t = false)]
    pub available_themes: bool,

    /// enable config file watching
    #[arg(long, help = "Watch Config File for Changes", default_value_t = false)]
    pub watch_config: bool,

    /// display-config
    #[arg(long, help = "Display Current Configuration", default_value_t = false)]
    pub display_config: bool,

    /// display-env
    #[arg(long, help = "Display Environment Variables", default_value_t = false)]
    pub display_env: bool,

    // display-defaults
    #[arg(long, help = "Display Default Settings", default_value_t = false)]
    pub display_defaults: bool,

    // display-prompt
    #[arg(long, help = "Display Current Prompt", default_value_t = false)]
    pub display_prompt: bool,
}

impl Arguments {
    pub fn new() -> Self {
        use clap::Parser;
        return Arguments::parse();
    }

    pub fn as_mutex(&self) -> std::sync::Arc<std::sync::Mutex<Self>> {
        std::sync::Arc::new(std::sync::Mutex::new(self.clone()))
    }

    pub fn is_debugging(&self) -> bool {
        self.debug || self.debug_expressions || self.debug_tokenization
    }

    pub fn _should_debug_tokens(&self) -> bool {
        self.debug || self.debug_tokenization
    }
    pub fn _should_debug_expressions(&self) -> bool {
        self.debug || self.debug_expressions
    }

    pub fn should_debug_context(&self) -> bool {
        self.debug || self.debug_context
    }

    pub fn _validate(&self) -> bool {
        true
    }
}

mod tests {
    use super::*;

    #[test]
    fn test_arguments_new() {
        let args = Arguments::new();
        assert!(args._validate());
    }
}
