/// Theme and Style management for Turtle shell
///
/// Copyright (c) 2025 Aaron P. Samuel
///
/// Licensed under the MIT License <LICENSE-MIT or http://opensource.org/licenses/MIT>
///
/// *SPDX-License-Identifier*: MIT
///
/// See LICENSE for details.
use serde::{Deserialize, Serialize};

/// Default themes included in the Turtle shell
pub const DEFAULT_THEMES: &str = include_str!("./data/themes.yaml");

/// Converts a hexadecimal color string to a `crossterm::style::Color::Rgb` struct
fn hex_to_rgb(hex: &str) -> Option<crossterm::style::Color> {
    let hex = hex.trim_start_matches('#');
    if hex.len() != 6 {
        return None;
    }
    let r = u8::from_str_radix(&hex[0..2], 16).ok()?;
    let g = u8::from_str_radix(&hex[2..4], 16).ok()?;
    let b = u8::from_str_radix(&hex[4..6], 16).ok()?;
    Some(crossterm::style::Color::Rgb { r, g, b })
}

/// Themese for Turtle shell
///
/// ```yaml
/// name: "Solarized Dark"
/// description: "A dark theme based on the Solarized color scheme"
/// foreground: "#839496"
/// background: "#002b36"
/// text: "#93a1a1"
/// cursor: "#93a1a1"
/// selection: "#073642"
/// ```
#[derive(Debug, Clone)]
pub struct Theme {
    pub name: String,
    pub description: String,
    pub foreground: crossterm::style::Color,
    pub background: crossterm::style::Color,
    pub text: crossterm::style::Color,
    pub cursor: crossterm::style::Color,
    pub selection: crossterm::style::Color,
}

impl Default for Theme {
    fn default() -> Self {
        Theme {
            name: "default".to_string(),
            description: "Default theme".to_string(),
            foreground: crossterm::style::Color::White,
            background: crossterm::style::Color::Black,
            text: crossterm::style::Color::White,
            cursor: crossterm::style::Color::White,
            selection: crossterm::style::Color::Grey,
        }
    }
}

impl std::fmt::Display for Theme {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "Theme: {}\nDescription: {}\nForeground: {:?}\nBackground: {:?}\nText: {:?}\nCursor: {:?}\nSelection: {:?}",
            self.name,
            self.description,
            self.foreground,
            self.background,
            self.text,
            self.cursor,
            self.selection
        )
    }
}

/// Manages themes for Turtle shell
#[derive(Debug, Clone)]
pub struct ThemeManager {
    pub current: String,
    pub themes: std::collections::HashMap<String, crate::style::Theme>,
}

impl ThemeManager {
    pub fn new() -> Self {
        let themes = std::collections::HashMap::from([
            (
                "solarized_dark".to_string(),
                crate::style::Theme {
                    name: "Solarized Dark".to_string(),
                    description: "A dark theme based on the Solarized color scheme".to_string(),
                    foreground: crossterm::style::Color::Rgb {
                        r: 131,
                        g: 148,
                        b: 150,
                    },
                    background: crossterm::style::Color::Rgb { r: 0, g: 43, b: 54 },
                    text: crossterm::style::Color::Rgb {
                        r: 147,
                        g: 161,
                        b: 161,
                    },
                    cursor: crossterm::style::Color::Rgb {
                        r: 147,
                        g: 161,
                        b: 161,
                    },
                    selection: crossterm::style::Color::Rgb { r: 7, g: 54, b: 66 },
                },
            ),
            (
                "solarized_light".to_string(),
                crate::style::Theme {
                    name: "Solarized Light".to_string(),
                    description: "A light theme based on the Solarized color scheme".to_string(),
                    foreground: crossterm::style::Color::Rgb {
                        r: 101,
                        g: 123,
                        b: 131,
                    },
                    background: crossterm::style::Color::Rgb {
                        r: 253,
                        g: 246,
                        b: 227,
                    },
                    text: crossterm::style::Color::Rgb {
                        r: 101,
                        g: 123,
                        b: 131,
                    },
                    cursor: crossterm::style::Color::Rgb {
                        r: 101,
                        g: 123,
                        b: 131,
                    },
                    selection: crossterm::style::Color::Rgb {
                        r: 238,
                        g: 232,
                        b: 213,
                    },
                },
            ),
            (
                "monokai".to_string(),
                crate::style::Theme {
                    name: "Monokai".to_string(),
                    description: "A dark theme based on the Monokai color scheme".to_string(),
                    foreground: crossterm::style::Color::Rgb {
                        r: 248,
                        g: 248,
                        b: 242,
                    },
                    background: crossterm::style::Color::Rgb {
                        r: 39,
                        g: 40,
                        b: 34,
                    },
                    text: crossterm::style::Color::Rgb {
                        r: 248,
                        g: 248,
                        b: 242,
                    },
                    cursor: crossterm::style::Color::Rgb {
                        r: 248,
                        g: 248,
                        b: 242,
                    },
                    selection: crossterm::style::Color::Rgb {
                        r: 73,
                        g: 72,
                        b: 62,
                    },
                },
            ),
            (
                "catppuccino".to_string(),
                crate::style::Theme {
                    name: "Catppuccino".to_string(),
                    description: "A light theme based on the Catppuccino color scheme".to_string(),
                    foreground: crossterm::style::Color::Rgb {
                        r: 75,
                        g: 56,
                        b: 50,
                    },
                    background: crossterm::style::Color::Rgb {
                        r: 241,
                        g: 224,
                        b: 214,
                    },
                    text: crossterm::style::Color::Rgb {
                        r: 75,
                        g: 56,
                        b: 50,
                    },
                    cursor: crossterm::style::Color::Rgb {
                        r: 75,
                        g: 56,
                        b: 50,
                    },
                    selection: crossterm::style::Color::Rgb {
                        r: 224,
                        g: 200,
                        b: 176,
                    },
                },
            ),
        ]);

        ThemeManager {
            current: "solarized_dark".to_string(),
            themes,
        }
    }

    pub fn list(&self) -> Vec<&String> {
        self.themes.keys().collect()
    }

    pub fn apply<W: std::io::Write>(
        &self,
        writer: &mut W,
        theme_name: &str,
    ) -> std::io::Result<()> {
        let theme = self
            .themes
            .get(theme_name)
            .or_else(|| self.themes.get(crate::config::DEFAULT_THEME));
        let theme = match theme {
            Some(theme) => theme,
            None => {
                return Err(std::io::Error::new(
                    std::io::ErrorKind::NotFound,
                    "Theme not found",
                ));
            }
        };

        crossterm::execute!(
            writer,
            crossterm::style::ResetColor,
            crossterm::style::SetForegroundColor(theme.foreground),
            crossterm::style::SetBackgroundColor(theme.background),
            crossterm::style::SetStyle(crossterm::style::ContentStyle {
                foreground_color: Some(theme.text),
                background_color: Some(theme.background),
                underline_color: None,
                attributes: crossterm::style::Attributes::default(),
            }),
            // crossterm::style::SetSelectionColor(theme.selection),
        )?;
        Ok(())
    }
}

impl From<&str> for ThemeManager {
    fn from(themes: &str) -> Self {
        // let reader = std::io::BufReader::new(file);
        // consume file definitions as HashMap<String, HashMap<String, String>>
        let themes_yaml: std::collections::HashMap<
            String,
            std::collections::HashMap<String, String>,
        > = serde_yaml::from_str(themes).unwrap();
        let themes = themes_yaml
            .into_iter()
            .map(|(name, props)| {
                let name = name.clone();
                let foreground = hex_to_rgb(props.get("foreground").unwrap()).unwrap();
                let background = hex_to_rgb(props.get("background").unwrap()).unwrap();
                let text = hex_to_rgb(props.get("text").unwrap()).unwrap();
                let cursor = hex_to_rgb(props.get("cursor").unwrap()).unwrap();
                let selection = hex_to_rgb(props.get("selection").unwrap()).unwrap();
                (
                    name.clone(),
                    crate::style::Theme {
                        name,
                        description: props.get("description").unwrap().to_string(),
                        foreground,
                        background,
                        text,
                        cursor,
                        selection,
                    },
                )
            })
            .collect();

        ThemeManager {
            current: String::new(),
            themes,
        }
    }
}

impl Default for ThemeManager {
    fn default() -> Self {
        ThemeManager::new()
    }
}
/// Turtle shell prompt
pub struct Prompt<'a> {
    template: &'a str,
}

impl<'a> Prompt<'a> {
    pub fn new(template: &'a str) -> Self {
        Prompt { template }
    }

    pub fn context(&self) -> PromptContext {
        PromptContext {
            ..PromptContext::default()
        }
    }

    pub fn render(&mut self) -> String {
        let context = self.context();
        let mut engine = tinytemplate::TinyTemplate::new();
        let template = self.template;
        engine.add_template("prompt", template);
        engine
            .render("prompt", &context)
            .unwrap_or_else(|_| template.to_string())
    }
}

/// Turtle shell prompt context
#[derive(Serialize, Deserialize)]
pub struct PromptContext {
    /// username
    pub uname: String,
    /// user id
    pub uid: u32,
    /// hostname
    pub hostname: String,
    /// current working directory
    pub cwd: String,
    /// current time
    pub time: String,
    /// turtle emoji
    pub turtle: String,
    /// system uptime
    pub uptime: String,
    /// system load average
    pub load_avg: String,
    /// number of jobs
    pub job_count: usize,
    /// last exit code
    pub last_exit_code: i32,
}

impl Default for PromptContext {
    fn default() -> Self {
        PromptContext {
            /* User Context */
            uname: whoami::username(),
            uid: users::get_current_uid(),
            /* Host Context */
            hostname: whoami::fallible::hostname().unwrap_or_else(|_| "?".into()),

            /* Environment Context */
            cwd: std::env::current_dir()
                .map(|path| path.display().to_string())
                .unwrap_or_else(|_| "?".to_string()),
            time: chrono::Local::now().format("%H:%M:%S").to_string(),
            uptime: "0:00".into(),
            load_avg: "0.00 0.00 0.00".into(),
            job_count: 0,
            last_exit_code: 0,

            /* Emoji Context */
            turtle: "🐢".into(),
        }
    }
}

impl PromptContext {
    pub fn list_fields() -> Vec<String> {
        let json = serde_json::to_value(PromptContext::default()).unwrap();
        json.as_object()
            .unwrap()
            .keys()
            .cloned()
            .collect::<Vec<String>>()
    }
}

impl std::fmt::Display for PromptContext {
    // prints the fields available for the prompt as a list
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        let fields = PromptContext::list_fields();
        write!(f, "Available fields: {}", fields.join(", "))
    }
}
