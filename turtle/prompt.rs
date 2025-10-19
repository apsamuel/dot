
use chrono::Local;
// use fallible::hostname;

pub fn expand_prompt_macros(prompt: &str) -> String {
  let username = whoami::username();
  let hostname = whoami::fallible::hostname().unwrap_or_else(|_| "?".into());
  let cwd = std::env::current_dir()
      .map(|path| path.display().to_string())
      .unwrap_or_else(|_| "?".to_string());
  let time = Local::now().format("%H:%M:%S").to_string();

  prompt
      .replace("{user}", &username)
      .replace("{host}", &hostname)
      .replace("{cwd}", &cwd)
      .replace("{time}", &time)
      .replace("{turtle}", "🐢")
}


pub fn get_default_prompt() -> String {
  expand_prompt_macros("{user}@{host}:{cwd} {turtle} -->")
}

pub fn redraw_prompt(prompt: &str) -> String {
  let prompt = expand_prompt_macros(prompt);
  prompt
}