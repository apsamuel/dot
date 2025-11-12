// use rustyline::config;

/// shell builtin commands
///
/// builtins are functions available in a shell session
pub struct Builtin {
    pub name: String,
    pub description: String,
    pub help: String,
    pub execute: Box<
        dyn Fn(
                std::sync::Arc<std::sync::Mutex<crate::config::Config>>, // config
                std::sync::Arc<std::sync::Mutex<crate::config::Arguments>>, // args
                std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>, // env
                std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>, // aliases
                std::sync::Arc<
                    std::sync::Mutex<
                        std::collections::HashMap<String, crate::expressions::Expressions>,
                    >,
                >, // vars
                std::sync::Arc<std::sync::Mutex<Vec<crate::history::Event>>>, // history TODO: replace this with history manager (Just pass History  reference)
                Vec<String>, // available builtin names
                Vec<String>, // args
                // TODO: consider passing context back into builtins instead of individual components
                bool, // debug
            ) + Send
            + Sync
            + 'static,
    >,
}

impl Builtin {
    pub fn get<'a>(name: &str, builtins: &'a [Builtin]) -> Option<&'a Builtin> {
        builtins.iter().find(|builtin| builtin.name == name)
    }

    pub fn get_builtin(name: &str, builtins: Vec<Builtin>) -> Option<Builtin> {
        for builtin in builtins {
            if builtin.name == name {
                return Some(builtin);
            }
        }
        None
    }
}

impl std::fmt::Debug for Builtin {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("TurtleBuiltin")
            .field("name", &self.name)
            .field("description", &self.description)
            .field("help", &self.help)
            .finish()
    }
}

// #[derive(Debug, Clone)]
pub struct Builtins {
    pub builtins: Vec<Builtin>,
    pub env: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    pub aliases: std::sync::Arc<std::sync::Mutex<std::collections::HashMap<String, String>>>,
    pub vars: std::sync::Arc<
        std::sync::Mutex<std::collections::HashMap<String, crate::expressions::Expressions>>,
    >,
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

    pub fn get(&self, name: &str) -> Option<&Builtin> {
        self.builtins.iter().find(|b| b.name == name)
    }

    pub fn list(&self) -> Vec<String> {
        self.builtins.iter().map(|b| b.name.clone()).collect()
    }

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
        history: std::sync::Arc<std::sync::Mutex<Vec<crate::history::Event>>>,
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
