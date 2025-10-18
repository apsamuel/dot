pub fn builtin_cd(args: &[&str]) {
  let home = std::env::var("HOME").unwrap();
  let dest = args.get(0).map(|s| *s).unwrap_or(home.as_str());
  if let Err(e) = std::env::set_current_dir(dest) {
      eprintln!("cd: {}: {}", dest, e);
  }
}

pub fn builtin_exit() {
  std::process::exit(0);
}


pub fn builtin_history() {
  match crate::history::load_history() {
    Ok(entries) => {
      for (i, entry) in entries.iter().enumerate() {
        println!("{}: {}", i + 1, entry);
      }
    }
    Err(e) => eprintln!("Error loading history: {}", e),

  }
}
