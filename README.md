# Dot

![dot](./data/images/black-sun.jpg)

> Because a shell deserves better than dad jokes, plain defaults and endless plugins.

## About

**`dot`** is a config automation framework that turns a default shell into your ***productivity powerhouse*** in seconds.

## Features

- 🔋 **Batteries Included**: We know what shell users want, and we include it out of the box.

  - Fuzzy finding
    - `fzf` fuzzy finding everything
    - `fzf-git` integrates fzf with common git operations like
  - Popular toolkits are vendored
    - `bash-commons` for stable and reusable shell tools
    - `oh-my-zsh` zsh theming and plugins
    - `oh-my-tmux` for terminal multiplexing
    - `bat` syntax highlighting in the terminal
  - Appearance
    - `powerlevel10k` for a prompt that tells you more than just the time
- 🎨 **Sleek & Modern**: A terminal experience so smooth, you'll think you're in a sci-fi movie 🎬
- ⚙️ **Highly Customizable**: Tweak it, bend it, make it yours. Your terminal, your rules 🛠️
- 🚀 **Performance Optimized**: Because nobody likes a slow shell

## Quick Start

```bash
chsh -s $(which zsh)  # Tell your system that zsh is your new best friend
source ~/.zshrc        # Let the magic begin
```

## What's Inside?

- 📚 Custom ZSH configurations that would make Linus Torvalds proud
- 🎮 Terminal customizations that look like they're from the future
- 🔧 Tools integration (bat, fzf, tmux) because raw terminal output is so 1970
- 🤖 Auto-completions that finish your commands before you even think of them

## Requirements

- A Unix-like operating system (Linux, macOS, BSD)
- ZSH installed (version 5.8 or higher recommended)
- A sense of humor (optional, but highly recommended)

## Installation

```bash
git clone https://github.com/apsamuel/dot.git ~/.dot
pushd ~/.dot
source ./bin/bootstrap.sh
```
