# Configuration Guide

Turtle can be configured via the `~/.turtlerc` file. This file allows you to customize various aspects of the Turtle shell, including prompt appearance, aliases, environment variables, and more.

## Environment Variables

You can set environment variables to configure Turtle's behavior. Environment variables can be set in your shell profile (e.g., `~/.zshrc`, `~/.bashrc`) or directly in the `~/.turtlerc` file. These varriables override arguments and settings in the configuration file. Here are some commonly used environment variables:

- `TURTLE_THEME`: Sets the color theme for the Turtle shell.
- `TURTLE_HISTORY_SIZE`: Specifies the number of commands to keep in history.
- `TURTLE_PROMPT`: Customizes the shell prompt format.

## Arguments

Turtle supports several command-line arguments that can be used to modify its behavior:

- **Exec Mode**
  - `--command <cmd>`: Execute a specific Turtle command and exit.
  - `--format <format>`: Set the output format (e.g., json, plain).
- **Interactive Mode**
  - `--theme <theme_name>`: Set the color theme for the Turtle shell.
  - `--config`: Specify a custom configuration file.
  - `--debug`: Enable debug mode for verbose output.
  - `--version`: Show the current version of Turtle.
  - `--help`: Display help information about Turtle and its commands.
