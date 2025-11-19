// use rustyline::config;

/// shell builtin commands
///
/// builtins are functions that can be executed within the turtle shell
pub struct Builtin {
    /// name of the builtin
    pub name: String,
    /// short description of the builtin
    pub description: String,
    /// help text for the builtin
    pub help: String,
    /// function to execute the builtin
    pub execute: Box<
        dyn Fn(
                // config
                std::sync::Arc<std::sync::Mutex<crate::config::Config>>,
                // args
                std::sync::Arc<std::sync::Mutex<crate::config::Arguments>>,
                // env
                std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
                // aliases
                std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
                // vars
                std::sync::Arc<
                    std::sync::Mutex<
                        std::collections::HashMap<String, crate::expressions::Expressions>,
                    >,
                >,
                // history
                std::sync::Arc<std::sync::Mutex<crate::history::History>>,
                // available builtin names
                Vec<String>,
                // arguments to the builtin
                Vec<String>,
                // TODO: consider passing context back into builtins instead of individual components
                bool, // debug
            ) + Send
            + Sync
            + 'static,
    >,
}

impl Builtin {
    pub fn _fields() -> Vec<String> {
        vec![
            "name".to_string(),
            "description".to_string(),
            "help".to_string(),
            "execute".to_string(),
        ]
    }
}

impl std::fmt::Debug for Builtin {
    /// format builtin outputs
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("TurtleBuiltin")
            .field("name", &self.name)
            .field("description", &self.description)
            .field("help", &self.help)
            .finish()
    }
}

/// encapsulates turtle builtins and methods of access
pub struct Builtins {
    /// available builtins
    pub builtins: Vec<Builtin>,
    /// environment variables
    pub env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    /// aliases
    pub aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    /// variables
    pub vars: std::sync::Arc<
        std::sync::Mutex<std::collections::HashMap<String, crate::expressions::Expressions>>,
    >,
    /// debug flag
    pub debug: bool,
}

impl std::fmt::Debug for Builtins {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("TurtleBuiltins")
            .field("builtins", &self.builtins)
            .finish()
    }
}

impl Builtins {
    /// create a new Builtins instance
    pub fn new(
        builtins: Vec<Builtin>,
        env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        vars: std::sync::Arc<
            std::sync::Mutex<std::collections::HashMap<String, crate::expressions::Expressions>>,
        >,
        debug: bool,
    ) -> Self {
        Builtins {
            builtins,
            env,
            aliases,
            vars,
            debug,
        }
    }

    /// get a builtin by name
    pub fn get(&self, name: &str) -> Option<&Builtin> {
        self.builtins.iter().find(|b| b.name == name)
    }

    /// list all builtin names
    pub fn list(&self) -> Vec<String> {
        self.builtins.iter().map(|b| b.name.clone()).collect()
    }

    /// execute a builtin by name
    pub fn exec(
        &self,
        name: &str,
        vars: std::sync::Arc<
            std::sync::Mutex<std::collections::HashMap<String, crate::expressions::Expressions>>,
        >,

        config: std::sync::Arc<std::sync::Mutex<crate::config::Config>>,
        turtle_args: std::sync::Arc<std::sync::Mutex<crate::config::Arguments>>,
        env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
        history: std::sync::Arc<std::sync::Mutex<crate::history::History>>,
        builtin_names: Vec<String>,
        args: Vec<String>,
    ) {
        let debug = self.debug;
        if let Some(builtin) = self.get(name) {
            (builtin.execute)(
                config,
                turtle_args,
                env,
                aliases,
                vars,
                history,
                builtin_names,
                args,
                debug,
            );
        } else {
            println!("Builtin command '{}' not found", name);
        }
    }
}
