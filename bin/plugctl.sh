#!/usr/bin/env bash

# shellcheck shell=bash

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	echo "Usage: plugin-add.sh"
	echo "Install themes and plugins for oh-my-zsh."
	exit 0
fi

## install themes and plugins for oh-my-zsh
