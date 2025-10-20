use std::io::{self, Write};
use once_cell::sync::Lazy;
use std::collections::HashMap;
use crossterm::execute;
use crossterm::style::{
  Color,
  SetForegroundColor,
  SetBackgroundColor,
  ResetColor,
  // Attribute
};

static DEFAULT_THEME: &str = "catppuccino";

static SOLARIZED_DARK: crate::types::TurtleTheme = crate::types::TurtleTheme {
    foreground: Color::Rgb { r: 131, g: 148, b: 150 },
    background: Color::Rgb { r: 0, g: 43, b: 54 },
    text: Color::Rgb { r: 147, g: 161, b: 161 },
    cursor: Color::Rgb { r: 147, g: 161, b: 161 },
    selection: Color::Rgb { r: 7, g: 54, b: 66 },
    // attributes: &["bold", "italic"],
};

static SOLARIZED_LIGHT: crate::types::TurtleTheme = crate::types::TurtleTheme {
    foreground: Color::Rgb { r: 101, g: 123, b: 131 },
    background: Color::Rgb { r: 253, g: 246, b: 227 },
    text: Color::Rgb { r: 101, g: 123, b: 131 },
    cursor: Color::Rgb { r: 101, g: 123, b: 131 },
    selection: Color::Rgb { r: 238, g: 232, b: 213 },
    // attributes: &["bold", "italic"],
};

static MONOKAI: crate::types::TurtleTheme = crate::types::TurtleTheme {
    foreground: Color::Rgb { r: 248, g: 248, b: 242 },
    background: Color::Rgb { r: 39, g: 40, b: 34 },
    text: Color::Rgb { r: 248, g: 248, b: 242 },
    cursor: Color::Rgb { r: 248, g: 248, b: 242 },
    selection: Color::Rgb { r: 73, g: 72, b: 62 },
    // attributes: &["bold"],
};

static CATPPUCCINO: crate::types::TurtleTheme = crate::types::TurtleTheme {
    foreground: Color::Rgb { r: 75, g: 56, b: 50 },
    background: Color::Rgb { r: 241, g: 224, b: 214 },
    text: Color::Rgb { r: 75, g: 56, b: 50 },
    cursor: Color::Rgb { r: 75, g: 56, b: 50 },
    selection: Color::Rgb { r: 224, g: 200, b: 176 },
    // attributes: &["italic"],
};

static TURTLE_THEMES: Lazy<HashMap<&'static str, &'static crate::types::TurtleTheme>> = Lazy::new(|| {
    let mut m = HashMap::new();
    m.insert("solarized_dark", &SOLARIZED_DARK);
    m.insert("solarized_light", &SOLARIZED_LIGHT);
    m.insert("monokai", &MONOKAI);
    m.insert("catppuccino", &CATPPUCCINO);
    m
});

// this should now take a string theme name and return the corresponding TurtleTheme struct
pub fn apply_theme<W: Write>(writer: &mut W, theme_name: &str) -> io::Result<()> {
    let theme = TURTLE_THEMES.get(theme_name).or_else(|| TURTLE_THEMES.get(DEFAULT_THEME));
    let theme = match theme {
        Some(theme) => theme,
        None => return Err(io::Error::new(io::ErrorKind::NotFound, "Theme not found")),
    };

    execute!(
        writer,
        ResetColor,
        SetForegroundColor(theme.foreground),
        SetBackgroundColor(theme.background),
    )?;
    // for attr in &theme.attributes {
    //     execute!(writer, Attribute::from_str(attr)?)?;
    // }
    Ok(())
}