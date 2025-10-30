use serde::Serialize;
/// Functions for logging and displaying command history
/// Uses a JSON file located at ~/.turtle_history.json
/// to store command requests and responses
use std::fs::OpenOptions;
use std::io::{self, Write};

use ratatui::{
    Terminal,
    backend::CrosstermBackend,
    // layout::{Layout, Constraint, Direction},
    style::{Color, Style},
    widgets::{Block, Borders, List, ListItem, ListState},
};

use crossterm::{
    event::{self, Event, KeyCode},
    execute,
    terminal::{EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode},
};

pub async fn log_history<T: Serialize>(entry: &T) {
    let home = dirs::home_dir().unwrap();
    let history_path = home.join(".turtle_history.json");
    let mut file = OpenOptions::new()
        .create(true)
        .append(true)
        .open(history_path)
        .unwrap();
    let json = serde_json::to_string(entry).unwrap();
    writeln!(file, "{}", json).unwrap();
}

/// Load command history from ~/.turtle_history.json
pub fn load_history() -> io::Result<Vec<serde_json::Value>> {
    let home = dirs::home_dir().unwrap();
    let history_path = home.join(".turtle_history.json");
    let content = std::fs::read_to_string(history_path)?;
    let mut history = Vec::new();
    for line in content.lines() {
        if let Ok(entry) = serde_json::from_str::<serde_json::Value>(line) {
            history.push(entry);
        }
    }
    Ok(history)
}

pub fn display_history_ui() -> std::io::Result<()> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;
    let history = load_history().unwrap_or_default();

    let mut offset = 0;
    let mut state = ListState::default();
    state.select(Some(offset));

    loop {
        terminal.draw(|f| {
            let size = f.area();
            let block = Block::default()
                .borders(Borders::ALL)
                .title("Command History");

            let items: Vec<ListItem> = history
                .iter()
                .skip(offset)
                .take((size.height - 2) as usize)
                .map(|entry| {
                    let content = format!("{}", entry);
                    ListItem::new(content)
                })
                .collect();
            let list = List::new(items)
                .block(block)
                .style(Style::default().fg(Color::Green))
                .highlight_style(Style::default().bg(Color::Yellow).fg(Color::Black));
            f.render_stateful_widget(list, size, &mut state);
        })?;

        if event::poll(std::time::Duration::from_millis(100))? {
            if let Event::Key(key) = event::read()? {
                match key.code {
                    KeyCode::Char('q') | KeyCode::Esc => break,
                    KeyCode::Down => {
                        if offset + 1 < history.len() {
                            offset += 1;
                        }
                    }
                    KeyCode::Up => {
                        if offset > 0 {
                            offset -= 1;
                        }
                    }
                    _ => {}
                }
                state.select(Some(offset));
            }
        }
    }

    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;
    Ok(())
}

pub fn clear_history() -> io::Result<()> {
    let home = dirs::home_dir().unwrap();
    let history_path = home.join(".turtle_history.json");
    OpenOptions::new()
        .create(true)
        .write(true)
        .truncate(true)
        .open(history_path)?;

    // check if the .turtle_history.txt file exists and clear it too
    let txt_history_path = home.join(".turtle_history.txt");
    if txt_history_path.exists() {
        OpenOptions::new()
            .create(true)
            .write(true)
            .truncate(true)
            .open(txt_history_path)?;
    }
    Ok(())
}

pub async fn _handle_key_events() {
    let history = load_history().unwrap_or_default();
    let mut history_index = history.len();
    let mut input = String::new();

    loop {
        if event::poll(std::time::Duration::from_millis(100)).unwrap() {
            if let Event::Key(key) = event::read().unwrap() {
                match key.code {
                    KeyCode::Up => {
                        if history_index > 0 {
                            history_index -= 1;
                            if let Some(entry) = history.get(history_index) {
                                if let Some(cmd) = entry.get("command") {
                                    input = cmd.as_str().unwrap_or("").to_string();
                                    println!("Setting input to: {}", input);
                                }
                            }
                        }
                    }
                    KeyCode::Down => {
                        if history_index + 1 < history.len() {
                            history_index += 1;
                            if let Some(entry) = history.get(history_index) {
                                if let Some(cmd) = entry.get("command") {
                                    input = cmd.as_str().unwrap_or("").to_string();
                                    println!("Setting input to: {}", input);
                                }
                            }
                        } else {
                            input.clear();
                            println!("Setting input to: {}", input);
                        }
                    }
                    _ => {}
                }
            }
        }
    }
}

pub fn export_history_for_rustyline(txt_path: &str) -> io::Result<()> {
    let history = load_history()?;
    let mut file = OpenOptions::new()
        .create(true)
        .write(true)
        .truncate(true)
        .open(txt_path)?;

    for entry in history {
        let event = entry.get("event").unwrap();

        if event != "command_request" {
            continue;
        }

        // when we export our history, we should write the command and its args before writing a new line
        let mut command = String::new();
        if let Some(cmd) = entry.get("command") {
            command.push_str(cmd.as_str().unwrap_or(""));
        }
        if let Some(args) = entry.get("args") {
            if let Some(arr) = args.as_array() {
                for arg in arr {
                    if let Some(s) = arg.as_str() {
                        command.push_str(&format!(" {}", s));
                    } else {
                        command.push_str(&format!(" {}", arg));
                    }
                }
            } else if let Some(s) = args.as_str() {
                command.push_str(&format!(" {}", s));
            }
            // command.push_str(&format!(" {}", args.as_str().unwrap_or("")));
        }
        writeln!(file, "{}", command)?;
    }
    Ok(())
}
