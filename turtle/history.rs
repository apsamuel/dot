use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct History {
    pub debug: bool,
    pub interval: Option<u64>,
    pub path: Option<String>,
    pub events: Option<Vec<Event>>,
}

impl History {
    pub fn new(path: Option<String>, interval: Option<u64>, debug: bool) -> Self {
        if let Some(p) = &path {
            let expanded_path = crate::utils::expand_path(p);
            // Self::load(debug, Some(expanded_path.clone()), interval);
            return History {
                debug,
                path: Some(expanded_path),
                events: Some(Vec::new()),
                interval,
            };
        } else {
            let defaults = crate::config::Defaults::default();
            return History {
                debug,
                path: Some(crate::utils::expand_path(&defaults.history_path)),
                events: Some(Vec::new()),
                interval,
            };
        }
    }

    /// loads history from file
    pub fn load(&mut self) -> Option<Vec<crate::history::Event>> {
        if self.path.is_none() {
            println!("❌ history path is not set.");
            return None;
        }

        if let Some(path) = &self.path {
            let content = std::fs::read_to_string(path).ok()?;
            let mut history = Vec::new();
            for line in content.lines() {
                match serde_json::from_str::<crate::history::Event>(line) {
                    Ok(event) => {
                        history.push(event);
                    }
                    Err(_e) => {
                        println!("❌ failed to parse event from line: {}", line);
                        continue;
                    }
                }
            }

            self.events = Some(history.clone());

            return Some(history.clone());
        }
        None
    }

    /// set up history and load existing events
    pub fn setup(&mut self) {
        if self.events.is_none() {
            self.events = Some(Vec::new());
        }
        // TODO: we should be using the default value here
        self.events = self.load();
    }

    /// add an event to history
    pub fn add(&mut self, event: Event) {
        if let Some(events) = &mut self.events {
            events.push(event);
        }
    }

    /// flush events to file periodically
    pub fn flush(&self) -> std::io::Result<()> {
        use std::io::Write;
        let duration = std::time::Duration::from_secs(self.interval.unwrap_or(60));
        let path = self.path.clone().unwrap();
        let events = self.events.clone().unwrap_or(Vec::new());
        let debug = self.debug;

        std::thread::spawn(move || {
            loop {
                if debug {
                    println!("Flushing history to file: {}", path);
                }

                std::thread::sleep(duration);
                let mut file = std::fs::OpenOptions::new()
                    .create(true)
                    // .append(true)
                    .open(&path)
                    .unwrap();
                for event in &events {
                    let json = serde_json::to_string(event).unwrap();

                    writeln!(file, "{}", json).unwrap();
                }
            }
        });
        Ok(())
    }

    /// serialize and save history to file
    pub fn save(&self) -> std::io::Result<()> {
        use std::io::Write;
        let expanded_path = crate::utils::expand_path(self.path.as_ref().unwrap());
        let mut file = std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(expanded_path)?;
        if let Some(events) = &self.events {
            for event in events {
                let json = serde_json::to_string(event).unwrap();
                writeln!(file, "{}", json)?;
            }
            Ok(())
        } else {
            Ok(())
        }
    }

    /// start periodic flushing of history to file
    pub fn start(&mut self) {
        self.setup();
        if let Some(interval) = self.interval {
            self.flush().ok();
            if self.debug {
                println!("✅ history flushing started every {} seconds", interval);
            }
        }
    }
}

/// outputs for expression results
#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "event")]
pub enum OutputResults {
    #[serde(rename = "command_response")]
    CommandResponse(CommandResponse),
    #[serde(rename = "turtle_expression")]
    TurtleExpression(crate::expressions::Expressions),
}

/// a command request to the shell
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct CommandRequest {
    pub id: String,
    pub command: String,
    pub args: Vec<String>,
    pub timestamp: u64,
    // pub event: String,
}

/// a command response from the shell
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct CommandResponse {
    pub id: String,
    pub status: String,
    pub code: i32,
    pub output: String,
    pub errors: String,
    pub timestamp: u64,
    // pub event: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "event")]

/// history event types
pub enum Event {
    // #[serde(rename = "command_request")]
    CommandRequest(CommandRequest),
    // #[serde(rename = "command_response")]
    CommandResponse(CommandResponse),
}

impl std::fmt::Display for Event {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Event::CommandRequest(req) => write!(
                f,
                "[{}] Command Request: {} {:?}",
                req.timestamp, req.command, req.args
            ),
            Event::CommandResponse(res) => write!(
                f,
                "[{}] Command Response: {} (code: {})",
                res.timestamp, res.output, res.code
            ),
        }
    }
}

/// helper methods for HistoryEvent
impl Event {
    pub fn category(&self) -> &str {
        match self {
            Event::CommandRequest(_) => "CommandRequest",
            Event::CommandResponse(_) => "CommandResponse",
        }
    }

    pub fn as_json(&self) -> serde_json::Value {
        match self {
            Event::CommandRequest(req) => serde_json::to_value(req).unwrap(),
            Event::CommandResponse(res) => serde_json::to_value(res).unwrap(),
        }
    }

    pub fn as_yaml(&self) -> serde_yaml::Value {
        match self {
            Event::CommandRequest(req) => serde_yaml::to_value(req).unwrap(),
            Event::CommandResponse(res) => serde_yaml::to_value(res).unwrap(),
        }
    }

    pub fn as_string(&self) -> String {
        match self {
            Event::CommandRequest(req) => format!("{:?}", req),
            Event::CommandResponse(res) => format!("{:?}", res),
        }
    }

    pub fn as_csv(&self) -> String {
        match self {
            Event::CommandRequest(req) => {
                let mut wtr = csv::Writer::from_writer(vec![]);
                wtr.serialize(req).unwrap();
                let data = String::from_utf8(wtr.into_inner().unwrap()).unwrap();
                data
            }
            Event::CommandResponse(res) => {
                let mut wtr = csv::Writer::from_writer(vec![]);
                wtr.serialize(res).unwrap();
                let data = String::from_utf8(wtr.into_inner().unwrap()).unwrap();
                data
            }
        }
    }
}
