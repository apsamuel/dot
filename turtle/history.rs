/// Functions for logging and displaying command history
/// Uses a JSON file located at ~/.turtle_history.json
/// to store command requests and responses
use std::fs::{OpenOptions};
use std::io::{self, Write};
use serde::{Serialize};

use ratatui::{
    backend::CrosstermBackend,
    Terminal,
    widgets::{Block, Borders, List, ListItem, ListState},
    // layout::{Layout, Constraint, Direction},
    style::{Style, Color},
};

use crossterm::{
    event::{self, Event, KeyCode},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
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

// load history from .turtle_history.json
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

pub fn display_history_ui()  -> std::io::Result<()>{
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;
    let history = load_history().unwrap_or_default();
    // collect onlly the CommandRequest entries
    // let command_requests: Vec<crate::types::CommandRequest> = history.iter().filter_map(|entry| {
    //     if entry.get("event").and_then(|e| e.as_str()) == Some("command_request") {
    //         serde_json::from_value(entry.clone()).ok()
    //     } else {
    //         None
    //     }
    // }).collect();
    // let command_responses: Vec<crate::types::CommandResponse> = history.iter().filter_map(|entry| {
    //     if entry.get("event").and_then(|e| e.as_str()) == Some("command_response") {
    //         serde_json::from_value(entry.clone()).ok()
    //     } else {
    //         None
    //     }
    // }).collect();

    let mut offset = 0;
    let mut state = ListState::default();
    state.select(Some(offset));

    loop {
      terminal.draw(|f| {
        let size = f.area();
        let block = Block::default().borders(Borders::ALL).title("Command History");

        let items: Vec<ListItem> = history.iter().skip(offset).take((size.height - 2) as usize).map(|entry| {
            let content = format!("{}", entry);
            ListItem::new(content)
        }).collect();
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

pub async fn handle_key_events() {
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
        if let Some(cmd) = entry.get("command") {
            writeln!(file, "{}", cmd.as_str().unwrap_or(""))?;
        }
    }
    Ok(())
}