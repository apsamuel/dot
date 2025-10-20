// use std::fs::{OpenOptieons};
// use std::io::{self, Write};
// use serde::{Serialize};

use ratatui::{
    backend::CrosstermBackend,
    Terminal,
    widgets::{Block, Borders},
    layout::{Layout, Constraint, Direction},
    style::{Style, Color},
};

use crossterm::{
    event::{self, Event, KeyCode},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};

pub fn display_file_browser_ui() -> std::io::Result<()> {
    // Placeholder for file browser UI implementation
    println!("File browser UI is not yet implemented.");
    Ok(())
}

pub fn display_text_editor_ui() -> std::io::Result<()> {
    // Placeholder for text editor UI implementation
    println!("Text editor UI is not yet implemented.");
    Ok(())
}

pub fn display_terminal_ui() -> std::io::Result<()> {
    use std::process::Command;

    enable_raw_mode()?;
    let mut stdout = std::io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;
    terminal.clear()?;

    let mut input = String::new();
    let mut output = String::new();

    loop {
        let cwd = std::env::current_dir()
            .map(|path| path.display().to_string())
            .unwrap_or_else(|_| "?".to_string());


        let status_line = format!("Turtle Terminal - CWD: {} - Press 'q' to quit", cwd);

        terminal.draw(|f| {
            let size = f.area();
            let chunks = Layout::default()
                .direction(Direction::Vertical)
                .margin(1)
                .constraints(
                    [
                        Constraint::Percentage(70),
                        Constraint::Percentage(20),
                        Constraint::Percentage(10),
                    ]
                    .as_ref(),
                )
                .split(size);

            // Output pane
            let output_widget = ratatui::widgets::Paragraph::new(output.clone())
                .block(Block::default().title("Output").borders(Borders::ALL))
                .style(Style::default().fg(Color::White).bg(Color::Black));
            f.render_widget(output_widget, chunks[0]);

            // Input pane
            let input_widget = ratatui::widgets::Paragraph::new(input.clone())
                .block(Block::default().title("Input").borders(Borders::ALL))
                .style(Style::default().fg(Color::Yellow).bg(Color::Black));
            f.render_widget(input_widget, chunks[1]);

            // Status pane
            let status_widget = ratatui::widgets::Paragraph::new(status_line)
                .block(Block::default().title("Status").borders(Borders::ALL))
                .style(Style::default().fg(Color::White).bg(Color::Black));
            f.render_widget(status_widget, chunks[2]);
        })?;

        if event::poll(std::time::Duration::from_millis(100))? {
            if let Event::Key(key) = event::read()? {
                match key.code {
                    KeyCode::Char('q') => break,
                    KeyCode::Char(c) => input.push(c),
                    KeyCode::Backspace => { input.pop(); },
                    KeyCode::Enter => {
                        // Run the command and capture output
                        if !input.trim().is_empty() {
                            let result = Command::new("sh")
                                .arg("-c")
                                .arg(input.trim())
                                .output();

                            match result {
                                Ok(cmd_out) => {
                                    let stdout = String::from_utf8_lossy(&cmd_out.stdout);
                                    let stderr = String::from_utf8_lossy(&cmd_out.stderr);
                                    output = format!("{}\n{}", stdout, stderr);
                                }
                                Err(e) => {
                                    output = format!("Error: {}", e);
                                }
                            }
                        }
                        input.clear();
                    }
                    _ => {}
                }
            }
        }
    }

    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;
    Ok(())
}
