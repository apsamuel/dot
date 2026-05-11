# ──────────────────────────────────────────────────────────────────────────────
# ⚫️ dot Makefile — idempotent install orchestration & vendor management
#
# Usage:
#   make                              # print help
#   make dot-bootstrap                # full install (mirrors bootstrapSystem)
#   DRY=1 make dot-bootstrap          # dry-run — prints planned actions, zero mutations
#   make dot-bootstrap-brew dot-bootstrap-deps dot-bootstrap-cloud   # run specific steps
#   DEBUG=1 make dot-bootstrap-zsh    # enable xtrace for a single step
#   make vim-list                     # vendor passthrough (vim)
#   make omz-sync-plugins             # vendor passthrough (oh-my-zsh)
#   make tmux-status                  # vendor passthrough (oh-my-tmux)
#   make tmux-add-plugin PLUGIN=owner/repo   # add a tmux plugin
#   make tmux-sync-plugins            # reconcile tmux plugins
#
# Parameters (env vars, combinable):
#   DRY=1         safe dry-run mode (sets DOT_DRY_RUN=1)
#   DEBUG=1       enable bash xtrace (-x)
#   DEPS=1        force reinstall brew bundle even if satisfied
#   LANG_DEPS=1   install pip/npm packages from data/zsh.yaml
#
# Vendor passthrough parameters:
#   PLUGIN=owner/repo   for vim-add / vim-rm
#   BUNDLE=shared|nvim  for vim-add / vim-rm
#   OWNER=<org>         for omz-add-plugin / omz-add-theme / omz-remove-*
#   REPO=<name>         for omz-add-plugin / omz-add-theme / omz-remove-*
#   EXEC=<cmd>          optional post-init command for omz-add-*
#
# Requires: GNU Make 3.81+ and /bin/bash
# ──────────────────────────────────────────────────────────────────────────────

SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help

# ── Project layout ────────────────────────────────────────────────────────────
DOT_DIR := $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))" && pwd)
BOOTSTRAP := $(DOT_DIR)/scripts/dot-bootstrap.sh

# ── Vendor directories ────────────────────────────────────────────────────────
VENDOR_VIM  := $(DOT_DIR)/vendor/vim
VENDOR_OMZ  := $(DOT_DIR)/vendor/oh-my-zsh
VENDOR_TMUX := $(DOT_DIR)/vendor/oh-my-tmux

# ── Parameter passthrough ─────────────────────────────────────────────────────
DRY       ?= 0
DEBUG     ?= 0
DEPS      ?= 0
LANG_DEPS ?= 0

# Vendor passthrough parameters
PLUGIN ?=
BUNDLE ?=
OWNER  ?=
REPO   ?=
EXEC   ?=

# Single-line preamble sourced at the start of every recipe.
# Sources dot-bootstrap.sh (defines all bootstrap* functions) and maps Make
# parameters → shell env vars consumed by those functions.
# NOTE: .ONESHELL requires Make 3.82+; macOS ships 3.81, so we use a single
# logical line (BOOT) expanded with semicolons to stay compatible.
BOOT := export DOT_DRY_RUN="$(DRY)" DOT_DEPS="$(DEPS)" DOT_INSTALL_LANG_DEPS="$(LANG_DEPS)" DOT_DIRECTORY="$(DOT_DIR)"; \
        source "$(BOOTSTRAP)"; \
        if [[ "$(DEBUG)" == "1" ]]; then set -x; fi

# ── Phony declarations ────────────────────────────────────────────────────────
.PHONY: help \
        dot-bootstrap-info dot-bootstrap-brew dot-bootstrap-deps dot-bootstrap-cask-deps \
        dot-bootstrap-cloud dot-bootstrap-submodules \
        dot-bootstrap-zsh dot-bootstrap-bash dot-bootstrap-shells \
        dot-bootstrap-ssh dot-bootstrap-git dot-bootstrap-gh dot-bootstrap-configs \
        dot-bootstrap-python dot-bootstrap-node dot-bootstrap-langs \
        dot-bootstrap-iterm dot-bootstrap-figlet dot-bootstrap-fonts dot-bootstrap-p10k \
        dot-bootstrap-omz dot-bootstrap-omz-plugins dot-bootstrap-tmux dot-bootstrap-vim \
        dot-bootstrap \
        vim-install vim-build vim-update vim-helptags vim-doctor \
        vim-list vim-plugins vim-add vim-rm vim-clean \
        omz-install omz-add-plugin omz-add-theme \
        omz-remove-plugin omz-remove-theme \
        omz-sync-plugins omz-sync-themes \
        tmux-install tmux-clean tmux-update tmux-status \
        tmux-add-plugin tmux-remove-plugin tmux-sync-plugins tmux-list-plugins

# ══════════════════════════════════════════════════════════════════════════════
# Help
# ══════════════════════════════════════════════════════════════════════════════

help: ## Show this help
	@echo "⚫️  dot — install orchestration & vendor management"
	@echo ""
	@echo "Usage:  [PARAMS] make <target> [target...]"
	@echo ""
	@echo "Parameters (env vars):"
	@echo "  DRY=1         dry-run mode (no filesystem mutations)"
	@echo "  DEBUG=1       enable xtrace"
	@echo "  DEPS=1        force reinstall brew bundle"
	@echo "  LANG_DEPS=1   install pip/npm packages"
	@echo ""
	@echo "Vendor parameters:"
	@echo "  PLUGIN=owner/repo   vim-add / vim-rm"
	@echo "  BUNDLE=shared|nvim  vim-add / vim-rm"
	@echo "  OWNER=<org>         omz-add-plugin / omz-add-theme"
	@echo "  REPO=<name>         omz-add-plugin / omz-add-theme"
	@echo "  EXEC=<cmd>          omz-add-* post-init command"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make dot-bootstrap                    # full install"
	@echo "  DRY=1 make dot-bootstrap              # plan everything, change nothing"
	@echo "  make dot-bootstrap-brew dot-bootstrap-deps  # run specific steps"
	@echo "  make vim-list                         # list vendored vim plugins"
	@echo "  make omz-sync-plugins                 # reconcile oh-my-zsh plugins"
	@echo "  make tmux-status                      # check tmux config health"

# ══════════════════════════════════════════════════════════════════════════════
# Install targets (pipeline order matches bootstrapSystem)
# ══════════════════════════════════════════════════════════════════════════════

dot-bootstrap-info: ## Preflight checks (arch, os, tools)
	@$(BOOT); bootstrapInfo

dot-bootstrap-brew: ## Ensure Homebrew is installed
	@$(BOOT); bootstrapCheckBrew

dot-bootstrap-deps: ## Reconcile CLI dependencies (data/Brewfile)
	@$(BOOT); bootstrapCheckDependencies

dot-bootstrap-cask-deps: ## Reconcile cask dependencies (data/Brewfile.cask)
	@$(BOOT); bootstrapCheckCaskDependencies

dot-bootstrap-cloud: ## Verify iCloud Drive and link ~/iCloud
	@$(BOOT); bootstrapCheckCloud

dot-bootstrap-submodules: ## Initialize git submodules
	@$(BOOT); bootstrapInitSubmodules

dot-bootstrap-zsh: ## Configure zsh (link zshrc, set login shell)
	@$(BOOT); bootstrapConfigureZsh

dot-bootstrap-bash: ## Configure bash (link bashrc)
	@$(BOOT); bootstrapConfigBash

dot-bootstrap-ssh: ## Link SSH config + keys from iCloud
	@$(BOOT); bootstrapCheckCloud && bootstrapConfigSsh

dot-bootstrap-git: ## Link gitconfig from iCloud
	@$(BOOT); bootstrapCheckCloud && bootstrapConfigGit

dot-bootstrap-gh: ## Link gh CLI config from iCloud
	@$(BOOT); bootstrapConfigGh

dot-bootstrap-python: ## Provision Python venv (uv)
	@$(BOOT); bootstrapConfigPython

dot-bootstrap-node: ## Provision Node via n
	@$(BOOT); bootstrapConfigNode

dot-bootstrap-iterm: ## Configure iTerm2
	@$(BOOT); bootstrapConfigIterm

dot-bootstrap-figlet: ## Verify figlet fonts (vendored)
	@$(BOOT); bootstrapConfigFiglet

dot-bootstrap-fonts: ## Install fonts from iCloud
	@$(BOOT); bootstrapCheckCloud && bootstrapInstallFonts

dot-bootstrap-p10k: ## Configure Powerlevel10k
	@$(BOOT); bootstrapCheckCloud && bootstrapConfigPowershell10K

dot-bootstrap-omz: ## Ensure oh-my-zsh is installed and linked
	@$(BOOT); bootstrapCheckOhMyZsh

dot-bootstrap-omz-plugins: ## Sync oh-my-zsh custom plugins (vendor dispatch)
	@$(MAKE) -C "$(VENDOR_OMZ)" sync-plugins

dot-bootstrap-tmux: ## Configure oh-my-tmux + tpm plugins (vendor dispatch)
	@$(MAKE) -C "$(VENDOR_TMUX)" install

dot-bootstrap-vim: ## Configure vim + neovim (vendor dispatch)
	@$(MAKE) -C "$(VENDOR_VIM)" install

# ══════════════════════════════════════════════════════════════════════════════
# Convenience groups
# ══════════════════════════════════════════════════════════════════════════════

dot-bootstrap-shells: dot-bootstrap-zsh dot-bootstrap-bash ## Configure all shells (zsh + bash)

dot-bootstrap-configs: dot-bootstrap-ssh dot-bootstrap-git dot-bootstrap-gh ## Link all configs (ssh, git, gh)

dot-bootstrap-langs: dot-bootstrap-python dot-bootstrap-node ## Provision language toolchains (python, node)

# ══════════════════════════════════════════════════════════════════════════════
# Full install (mirrors bootstrapSystem pipeline)
# ══════════════════════════════════════════════════════════════════════════════

dot-bootstrap: ## Full install (all steps, fails fast)
	@$(BOOT); bootstrapPrint; bootstrapInfo; bootstrapSystem

# ══════════════════════════════════════════════════════════════════════════════
# Vendor passthrough — vim  (vendor/vim/Makefile)
# ══════════════════════════════════════════════════════════════════════════════

vim-install: ## [vim] Run install.sh (symlinks + submodules + build)
	@$(MAKE) -C "$(VENDOR_VIM)" install

vim-build: ## [vim] Compile native artifacts
	@$(MAKE) -C "$(VENDOR_VIM)" build

vim-update: ## [vim] Pull latest submodules, then rebuild
	@$(MAKE) -C "$(VENDOR_VIM)" update

vim-helptags: ## [vim] Regenerate vim/nvim helptags
	@$(MAKE) -C "$(VENDOR_VIM)" helptags

vim-doctor: ## [vim] Run plugin-status + :checkhealth
	@$(MAKE) -C "$(VENDOR_VIM)" doctor

vim-list: ## [vim] List vendored plugins
	@$(MAKE) -C "$(VENDOR_VIM)" list

vim-plugins: ## [vim] Show staged plugins each editor loads
	@$(MAKE) -C "$(VENDOR_VIM)" plugins

vim-add: ## [vim] Vendor a new plugin (PLUGIN=owner/repo BUNDLE=shared|nvim)
	@$(MAKE) -C "$(VENDOR_VIM)" add PLUGIN="$(PLUGIN)" BUNDLE="$(BUNDLE)"

vim-rm: ## [vim] Remove a vendored plugin (PLUGIN=name BUNDLE=shared|nvim)
	@$(MAKE) -C "$(VENDOR_VIM)" rm PLUGIN="$(PLUGIN)" BUNDLE="$(BUNDLE)"

vim-clean: ## [vim] Remove ~/.vim and ~/.config/nvim symlinks
	@$(MAKE) -C "$(VENDOR_VIM)" clean

# ══════════════════════════════════════════════════════════════════════════════
# Vendor passthrough — oh-my-zsh  (vendor/oh-my-zsh/Makefile)
# ══════════════════════════════════════════════════════════════════════════════

omz-install: ## [omz] Initialize and update all submodules
	@$(MAKE) -C "$(VENDOR_OMZ)" install

omz-add-plugin: ## [omz] Add a custom plugin (OWNER, REPO required; EXEC optional)
	@$(MAKE) -C "$(VENDOR_OMZ)" add-plugin OWNER="$(OWNER)" REPO="$(REPO)" EXEC="$(EXEC)"

omz-add-theme: ## [omz] Add a custom theme (OWNER, REPO required; EXEC optional)
	@$(MAKE) -C "$(VENDOR_OMZ)" add-theme OWNER="$(OWNER)" REPO="$(REPO)" EXEC="$(EXEC)"

omz-remove-plugin: ## [omz] Remove a custom plugin (OWNER, REPO required)
	@$(MAKE) -C "$(VENDOR_OMZ)" remove-plugin OWNER="$(OWNER)" REPO="$(REPO)"

omz-remove-theme: ## [omz] Remove a custom theme (OWNER, REPO required)
	@$(MAKE) -C "$(VENDOR_OMZ)" remove-theme OWNER="$(OWNER)" REPO="$(REPO)"

omz-sync-plugins: ## [omz] Reconcile plugin submodules from data file
	@$(MAKE) -C "$(VENDOR_OMZ)" sync-plugins

omz-sync-themes: ## [omz] Reconcile theme submodules from data file
	@$(MAKE) -C "$(VENDOR_OMZ)" sync-themes

# ══════════════════════════════════════════════════════════════════════════════
# Vendor passthrough — oh-my-tmux  (vendor/oh-my-tmux/Makefile)
# ══════════════════════════════════════════════════════════════════════════════

tmux-install: ## [tmux] Link configs → ~ + sync plugin submodules
	@$(MAKE) -C "$(VENDOR_TMUX)" install

tmux-clean: ## [tmux] Remove tmux config symlinks
	@$(MAKE) -C "$(VENDOR_TMUX)" clean

tmux-update: ## [tmux] Update declared plugin submodules
	@$(MAKE) -C "$(VENDOR_TMUX)" update

tmux-status: ## [tmux] Check tmux config health + plugin status
	@$(MAKE) -C "$(VENDOR_TMUX)" status

tmux-add-plugin: ## [tmux] Declare + clone a plugin (PLUGIN=owner/repo)
	@$(MAKE) -C "$(VENDOR_TMUX)" add-plugin PLUGIN="$(PLUGIN)"

tmux-remove-plugin: ## [tmux] Undeclare + remove a plugin (PLUGIN=owner/repo)
	@$(MAKE) -C "$(VENDOR_TMUX)" remove-plugin PLUGIN="$(PLUGIN)"

tmux-sync-plugins: ## [tmux] Reconcile declared ↔ on-disk plugin submodules
	@$(MAKE) -C "$(VENDOR_TMUX)" sync-plugins

tmux-list-plugins: ## [tmux] Show declared vs installed plugins
	@$(MAKE) -C "$(VENDOR_TMUX)" list-plugins
