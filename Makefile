# ──────────────────────────────────────────────────────────────────────────────
# ⚫️ dot Makefile — idempotent bootstrap orchestration
#
# Usage:
#   make                     # print help
#   make bootstrap           # full bootstrap (mirrors bootstrapSystem)
#   DRY=1 make bootstrap     # dry-run — prints planned actions, zero mutations
#   make brew deps cloud     # run specific targets in order
#   DEBUG=1 make zsh         # enable xtrace for a single step
#
# Parameters (env vars, combinable):
#   DRY=1         safe dry-run mode (sets DOT_DRY_RUN=1)
#   DEBUG=1       enable bash xtrace (-x)
#   DEPS=1        force reinstall brew bundle even if satisfied
#   LANG_DEPS=1   install pip/npm packages from data/zsh.yaml
#
# Requires: GNU Make 3.81+ and /bin/bash
# ──────────────────────────────────────────────────────────────────────────────

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

# ── Project layout ────────────────────────────────────────────────────────────
DOT_DIR := $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))" && pwd)
BOOTSTRAP := $(DOT_DIR)/scripts/dot-bootstrap.sh

# ── Parameter passthrough ─────────────────────────────────────────────────────
DRY       ?= 0
DEBUG     ?= 0
DEPS      ?= 0
LANG_DEPS ?= 0

# Single-line preamble sourced at the start of every recipe.
# Sources dot-bootstrap.sh (defines all bootstrap* functions) and maps Make
# parameters → shell env vars consumed by those functions.
# NOTE: .ONESHELL requires Make 3.82+; macOS ships 3.81, so we use a single
# logical line (BOOT) expanded with semicolons to stay compatible.
BOOT := export DOT_DRY_RUN="$(DRY)" DOT_DEPS="$(DEPS)" DOT_INSTALL_LANG_DEPS="$(LANG_DEPS)" DOT_DIRECTORY="$(DOT_DIR)"; \
        source "$(BOOTSTRAP)"; \
        if [[ "$(DEBUG)" == "1" ]]; then set -x; fi

# ── Phony declarations ────────────────────────────────────────────────────────
.PHONY: help info brew deps cask-deps cloud submodules \
        zsh bash shells ssh git gh configs \
        python node langs \
        iterm figlet fonts p10k \
        omz omz-plugins tmux vim \
        bootstrap

# ══════════════════════════════════════════════════════════════════════════════
# Help
# ══════════════════════════════════════════════════════════════════════════════

help: ## Show this help
	@echo "⚫️  dot bootstrap — Makefile interface"
	@echo ""
	@echo "Usage:  [PARAMS] make <target> [target...]"
	@echo ""
	@echo "Parameters (env vars):"
	@echo "  DRY=1         dry-run mode (no filesystem mutations)"
	@echo "  DEBUG=1       enable xtrace"
	@echo "  DEPS=1        force reinstall brew bundle"
	@echo "  LANG_DEPS=1   install pip/npm packages"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make bootstrap            # full bootstrap"
	@echo "  DRY=1 make bootstrap      # plan everything, change nothing"
	@echo "  make brew deps cloud      # run specific steps"
	@echo "  DRY=1 make ssh git        # preview config linking"

# ══════════════════════════════════════════════════════════════════════════════
# Individual targets (pipeline order matches bootstrapSystem)
# ══════════════════════════════════════════════════════════════════════════════

info: ## Preflight checks (arch, os, tools)
	@$(BOOT); bootstrapInfo

brew: ## Ensure Homebrew is installed
	@$(BOOT); bootstrapCheckBrew

deps: ## Reconcile CLI dependencies (data/Brewfile)
	@$(BOOT); bootstrapCheckDependencies

cask-deps: ## Reconcile cask dependencies (data/Brewfile.cask)
	@$(BOOT); bootstrapCheckCaskDependencies

cloud: ## Verify iCloud Drive and link ~/iCloud
	@$(BOOT); bootstrapCheckCloud

submodules: ## Initialize git submodules
	@$(BOOT); bootstrapInitSubmodules

zsh: ## Configure zsh (link zshrc, set login shell)
	@$(BOOT); bootstrapConfigureZsh

bash: ## Configure bash (link bashrc)
	@$(BOOT); bootstrapConfigBash

ssh: ## Link SSH config + keys from iCloud
	@$(BOOT); bootstrapCheckCloud && bootstrapConfigSsh

git: ## Link gitconfig from iCloud
	@$(BOOT); bootstrapCheckCloud && bootstrapConfigGit

gh: ## Link gh CLI config from iCloud
	@$(BOOT); bootstrapConfigGh

python: ## Provision Python venv (uv)
	@$(BOOT); bootstrapConfigPython

node: ## Provision Node via n
	@$(BOOT); bootstrapConfigNode

iterm: ## Configure iTerm2
	@$(BOOT); bootstrapConfigIterm

figlet: ## Verify figlet fonts (vendored)
	@$(BOOT); bootstrapConfigFiglet

fonts: ## Install fonts from iCloud
	@$(BOOT); bootstrapCheckCloud && bootstrapInstallFonts

p10k: ## Configure Powerlevel10k
	@$(BOOT); bootstrapCheckCloud && bootstrapConfigPowershell10K

omz: ## Ensure oh-my-zsh is installed and linked
	@$(BOOT); bootstrapCheckOhMyZsh

omz-plugins: ## Sync oh-my-zsh custom plugin submodules
	@$(BOOT); bootstrapInstallOhMyZshCustomPlugins

tmux: ## Configure oh-my-tmux + tpm plugins
	@$(BOOT); bootstrapCheckOhMyTmux

vim: ## Configure vim + neovim (vendored)
	@$(BOOT); bootstrapCheckVim

# ══════════════════════════════════════════════════════════════════════════════
# Convenience groups
# ══════════════════════════════════════════════════════════════════════════════

shells: zsh bash ## Configure all shells (zsh + bash)

configs: ssh git gh ## Link all configs (ssh, git, gh)

langs: python node ## Provision language toolchains (python, node)

# ══════════════════════════════════════════════════════════════════════════════
# Full bootstrap (mirrors bootstrapSystem pipeline)
# ══════════════════════════════════════════════════════════════════════════════

bootstrap: ## Full bootstrap (all steps, fails fast)
	@$(BOOT); bootstrapPrint; bootstrapInfo; bootstrapSystem
