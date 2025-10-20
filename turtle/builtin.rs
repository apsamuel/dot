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

pub fn builtin_alias(aliases: &mut std::collections::HashMap<String, String>, args: &[&str]) -> std::collections::HashMap<String, String> {
  if args.is_empty() {
    println!("no aliases provided");
  }

  if args.len() == 1 {
    if args.contains(&"=") {
      let parts: Vec<&str> = args[0].splitn(2, '=').collect();
      if parts.len() == 2 {
        let name = parts[0];
        let command = parts[1].trim_matches('"');
        aliases.insert(name.to_string(), command.to_string());
        return aliases.clone();
      }
    }
  }

  if args.len() == 2 {
    let name = args[0];
    let command = args[1].trim_matches('"');
    aliases.insert(name.to_string(), command.to_string());
    return aliases.clone();
  }

  println!("invalid alias format");
  aliases.clone()

}