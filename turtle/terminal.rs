pub struct TerminalManager {
    size: (u16, u16), // (cols, rows)
}

impl TerminalManager {
    pub fn new() -> Self {
        let (cols, rows) = crossterm::terminal::size().unwrap_or((80, 24));
        TerminalManager { size: (cols, rows) }
    }

    pub fn get_size(&self) -> (u16, u16) {
        self.size
    }
}
