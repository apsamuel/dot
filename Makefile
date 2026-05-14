# ──────────────────────────────────────────────────────────────────────────────
# ⚫️ dot Makefile — idempotent install orchestration & vendor management
#
# Usage:
#   make                              # print help
#   make dot-bootstrap                # full install (mirrors run)
#   DRY=1 make dot-bootstrap          # dry-run — prints planned actions, zero mutations
#   make check-brew check-deps check-cloud   # run specific steps
#   DEBUG=1 make config-zsh           # enable xtrace for a single step
#   make vim-list                     # vendor passthrough (vim)
#   make omz-sync-plugins             # vendor passthrough (oh-my-zsh)
#   make tmux-status                  # vendor passthrough (oh-my-tmux)
#   make tmux-add-plugin PLUGIN=owner/repo   # add a tmux plugin
#   make tmux-sync-plugins            # reconcile tmux plugins
#   make dry-run-verify               # CI target: verify zero mutations in DRY=1 mode
#   make doctor                       # read-only health check: deps, symlinks, submodules
#
# Parameters (env vars, combinable):
#   DRY=1         safe dry-run mode (sets DOT_DRY_RUN=1)
#   DEBUG=1       enable bash xtrace (-x)
#   VERBOSE=1     enable verbose output in vendor flows
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
VERBOSE   ?= 0
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

# Shared env propagation for all vendor sub-makes.
VENDOR_FLAGS := DRY="$(DRY)" DEBUG="$(DEBUG)" VERBOSE="$(VERBOSE)" DOT_DRY_RUN="$(DRY)" DOT_DEBUG="$(DEBUG)" DOT_VERBOSE="$(VERBOSE)"

# ── Phony declarations ────────────────────────────────────────────────────────
.PHONY: help \
        preflight check-brew check-deps check-cask-deps \
        check-cloud init-submodules \
        config-zsh config-bash config-shells \
        config-ssh config-git config-gh config-configs \
        config-python config-node config-langs \
        config-iterm config-figlet install-fonts config-p10k check-p10k \
        check-omz check-omtmux config-omz-plugins config-tmux config-vim \
        dot-bootstrap \
        vim-install vim-build vim-update vim-helptags vim-doctor \
        vim-list vim-plugins vim-add vim-rm vim-clean \
        omz-install omz-add-plugin omz-add-theme \
        omz-remove-plugin omz-remove-theme \
        omz-sync-plugins omz-sync-themes omz-doctor \
        tmux-install tmux-clean tmux-update tmux-status tmux-doctor \
        tmux-add-plugin tmux-remove-plugin tmux-sync-plugins tmux-list-plugins \
        doctor

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
	@echo "  VERBOSE=1     enable verbose vendor output"
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
	@echo "  make check-brew check-deps  # run specific steps"
	@echo "  make vim-list                         # list vendored vim plugins"
	@echo "  make omz-sync-plugins                 # reconcile oh-my-zsh plugins"
	@echo "  make tmux-status                      # check tmux config health"
	@echo "  make doctor                           # read-only system health check"

# ══════════════════════════════════════════════════════════════════════════════
# Install targets (pipeline order matches run)
# ══════════════════════════════════════════════════════════════════════════════

preflight: ## Preflight checks (arch, os, tools)
	@$(BOOT); preflight

check-brew: ## Ensure Homebrew is installed
	@$(BOOT); check_brew

check-deps: ## Reconcile CLI dependencies (data/Brewfile)
	@$(BOOT); check_deps

check-cask-deps: ## Reconcile cask dependencies (data/Brewfile.cask)
	@$(BOOT); check_cask_deps

check-cloud: ## Verify iCloud Drive and link ~/iCloud
	@$(BOOT); check_cloud

init-submodules: ## Initialize git submodules
	@$(BOOT); init_submodules

config-zsh: ## Configure zsh (link zshrc, set login shell)
	@$(BOOT); config_zsh

config-bash: ## Configure bash (link bashrc)
	@$(BOOT); config_bash

config-ssh: ## Link SSH config + keys from iCloud
	@$(BOOT); check_cloud && config_ssh

config-git: ## Link gitconfig from iCloud
	@$(BOOT); check_cloud && config_git

config-xdg: ## Link iCloud configs into XDG_CONFIG_HOME
	@$(BOOT); check_cloud && config_xdg

config-gh: ## Link gh CLI config from iCloud (via config_xdg)
	@$(BOOT); check_cloud && config_xdg gh

config-python: ## Provision Python venv (uv)
	@$(BOOT); config_python

config-node: ## Provision Node via n
	@$(BOOT); config_node

config-iterm: ## Configure iTerm2
	@$(BOOT); config_iterm

config-figlet: ## Verify figlet fonts (vendored)
	@$(BOOT); config_figlet

install-fonts: ## Install fonts from iCloud
	@$(BOOT); check_cloud && install_fonts

config-p10k: ## Configure Powerlevel10k
	@$(BOOT); check_cloud && config_p10k

check-p10k: ## Verify p10k config symlink (~/.p10k.zsh)
	@$(BOOT); check_p10k

check-omz: ## Ensure oh-my-zsh is installed and linked
	@$(BOOT); check_omz

check-omtmux: ## Verify oh-my-tmux config + tpm plugins
	@$(BOOT); check_omtmux

config-omz-plugins: ## Sync oh-my-zsh custom plugins (vendor dispatch)
	@$(MAKE) -C "$(VENDOR_OMZ)" sync-plugins $(VENDOR_FLAGS)

config-tmux: ## Configure oh-my-tmux + tpm plugins (vendor dispatch)
	@$(MAKE) -C "$(VENDOR_TMUX)" install $(VENDOR_FLAGS)

config-vim: ## Configure vim + neovim (vendor dispatch)
	@$(MAKE) -C "$(VENDOR_VIM)" install $(VENDOR_FLAGS)

# ══════════════════════════════════════════════════════════════════════════════
# Convenience groups
# ══════════════════════════════════════════════════════════════════════════════

config-shells: config-zsh config-bash ## Configure all shells (zsh + bash)

config-configs: config-ssh config-git config-gh ## Link all configs (ssh, git, gh)

config-langs: config-python config-node ## Provision language toolchains (python, node)

# ══════════════════════════════════════════════════════════════════════════════
# Full install (mirrors run pipeline)
# ══════════════════════════════════════════════════════════════════════════════

dot-bootstrap: ## Full install (all steps, fails fast)
	@$(BOOT); print_banner; preflight; run

# ══════════════════════════════════════════════════════════════════════════════
# Vendor passthrough — vim  (vendor/vim/Makefile)
# ══════════════════════════════════════════════════════════════════════════════

vim-install: ## [vim] Run install.sh (symlinks + submodules + build)
	@$(MAKE) -C "$(VENDOR_VIM)" install $(VENDOR_FLAGS)

vim-build: ## [vim] Compile native artifacts
	@$(MAKE) -C "$(VENDOR_VIM)" build $(VENDOR_FLAGS)

vim-update: ## [vim] Pull latest submodules, then rebuild
	@$(MAKE) -C "$(VENDOR_VIM)" update $(VENDOR_FLAGS)

vim-helptags: ## [vim] Regenerate vim/nvim helptags
	@$(MAKE) -C "$(VENDOR_VIM)" helptags $(VENDOR_FLAGS)

vim-doctor: ## [vim] Run plugin-status + :checkhealth
	@$(MAKE) -C "$(VENDOR_VIM)" doctor $(VENDOR_FLAGS)

vim-list: ## [vim] List vendored plugins
	@$(MAKE) -C "$(VENDOR_VIM)" list $(VENDOR_FLAGS)

vim-plugins: ## [vim] Show staged plugins each editor loads
	@$(MAKE) -C "$(VENDOR_VIM)" plugins $(VENDOR_FLAGS)

vim-add: ## [vim] Vendor a new plugin (PLUGIN=owner/repo BUNDLE=shared|nvim)
	@$(MAKE) -C "$(VENDOR_VIM)" add PLUGIN="$(PLUGIN)" BUNDLE="$(BUNDLE)" $(VENDOR_FLAGS)

vim-rm: ## [vim] Remove a vendored plugin (PLUGIN=name BUNDLE=shared|nvim)
	@$(MAKE) -C "$(VENDOR_VIM)" rm PLUGIN="$(PLUGIN)" BUNDLE="$(BUNDLE)" $(VENDOR_FLAGS)

vim-clean: ## [vim] Remove ~/.vim and ~/.config/nvim symlinks
	@$(MAKE) -C "$(VENDOR_VIM)" clean $(VENDOR_FLAGS)

# ══════════════════════════════════════════════════════════════════════════════
# Vendor passthrough — oh-my-zsh  (vendor/oh-my-zsh/Makefile)
# ══════════════════════════════════════════════════════════════════════════════

omz-install: ## [omz] Initialize and update all submodules
	@$(MAKE) -C "$(VENDOR_OMZ)" install $(VENDOR_FLAGS)

omz-add-plugin: ## [omz] Add a custom plugin (OWNER, REPO required; EXEC optional)
	@$(MAKE) -C "$(VENDOR_OMZ)" add-plugin OWNER="$(OWNER)" REPO="$(REPO)" EXEC="$(EXEC)" $(VENDOR_FLAGS)

omz-add-theme: ## [omz] Add a custom theme (OWNER, REPO required; EXEC optional)
	@$(MAKE) -C "$(VENDOR_OMZ)" add-theme OWNER="$(OWNER)" REPO="$(REPO)" EXEC="$(EXEC)" $(VENDOR_FLAGS)

omz-remove-plugin: ## [omz] Remove a custom plugin (OWNER, REPO required)
	@$(MAKE) -C "$(VENDOR_OMZ)" remove-plugin OWNER="$(OWNER)" REPO="$(REPO)" $(VENDOR_FLAGS)

omz-remove-theme: ## [omz] Remove a custom theme (OWNER, REPO required)
	@$(MAKE) -C "$(VENDOR_OMZ)" remove-theme OWNER="$(OWNER)" REPO="$(REPO)" $(VENDOR_FLAGS)

omz-sync-plugins: ## [omz] Reconcile plugin submodules from data file
	@$(MAKE) -C "$(VENDOR_OMZ)" sync-plugins $(VENDOR_FLAGS)

omz-sync-themes: ## [omz] Reconcile theme submodules from data file
	@$(MAKE) -C "$(VENDOR_OMZ)" sync-themes $(VENDOR_FLAGS)

omz-doctor: ## [omz] Read-only health check (plugins, themes, submodules)
	@$(MAKE) -C "$(VENDOR_OMZ)" doctor $(VENDOR_FLAGS)

# ══════════════════════════════════════════════════════════════════════════════
# Vendor passthrough — oh-my-tmux  (vendor/oh-my-tmux/Makefile)
# ══════════════════════════════════════════════════════════════════════════════

tmux-install: ## [tmux] Link configs → ~ + sync plugin submodules
	@$(MAKE) -C "$(VENDOR_TMUX)" install $(VENDOR_FLAGS)

tmux-clean: ## [tmux] Remove tmux config symlinks
	@$(MAKE) -C "$(VENDOR_TMUX)" clean $(VENDOR_FLAGS)

tmux-update: ## [tmux] Update declared plugin submodules
	@$(MAKE) -C "$(VENDOR_TMUX)" update $(VENDOR_FLAGS)

tmux-status: ## [tmux] Check tmux config health + plugin status
	@$(MAKE) -C "$(VENDOR_TMUX)" status $(VENDOR_FLAGS)

tmux-add-plugin: ## [tmux] Declare + clone a plugin (PLUGIN=owner/repo)
	@$(MAKE) -C "$(VENDOR_TMUX)" add-plugin PLUGIN="$(PLUGIN)" $(VENDOR_FLAGS)

tmux-remove-plugin: ## [tmux] Undeclare + remove a plugin (PLUGIN=owner/repo)
	@$(MAKE) -C "$(VENDOR_TMUX)" remove-plugin PLUGIN="$(PLUGIN)" $(VENDOR_FLAGS)

tmux-sync-plugins: ## [tmux] Reconcile declared ↔ on-disk plugin submodules
	@$(MAKE) -C "$(VENDOR_TMUX)" sync-plugins $(VENDOR_FLAGS)

tmux-list-plugins: ## [tmux] Show declared vs installed plugins
	@$(MAKE) -C "$(VENDOR_TMUX)" list-plugins $(VENDOR_FLAGS)

tmux-doctor: ## [tmux] Read-only health check (tmux, symlinks, plugins)
	@$(MAKE) -C "$(VENDOR_TMUX)" doctor $(VENDOR_FLAGS)

# ══════════════════════════════════════════════════════════════════════════════
# Doctor — non-mutating health check
# ══════════════════════════════════════════════════════════════════════════════

doctor: ## Non-mutating health check: deps, symlinks, submodules, vendors
	@$(BOOT); \
	fails=0; \
	echo ""; \
	say_step "dot doctor"; \
	echo ""; \
	say_step "tier-0 dependencies"; \
	if "$(DOT_DIR)/scripts/dot-deps-report.sh" --tier 0 -q; then \
		say_ok "all tier-0 dependencies present"; \
	else \
		say_err "tier-0 dependency check failed"; \
		fails=$$((fails + 1)); \
	fi; \
	echo ""; \
	say_step "core symlinks"; \
	for pair in "$$HOME/.zshrc:$(DOT_DIR)/zshrc" "$$HOME/.oh-my-zsh:$(VENDOR_OMZ)"; do \
		link="$${pair%%:*}"; expected="$${pair#*:}"; \
		if [ -L "$$link" ]; then \
			target=$$(readlink "$$link"); \
			if [ "$$target" = "$$expected" ]; then \
				say_ok "$$link → $$target"; \
			else \
				say_err "$$link → $$target (expected $$expected)"; \
				fails=$$((fails + 1)); \
			fi; \
		elif [ -e "$$link" ]; then \
			say_err "$$link exists but is NOT a symlink"; \
			fails=$$((fails + 1)); \
		else \
			say_err "$$link missing"; \
			fails=$$((fails + 1)); \
		fi; \
	done; \
	if [ -d "$$HOME/iCloud" ]; then \
		say_ok "~/iCloud exists"; \
	else \
		say_warn "~/iCloud not found (optional)"; \
	fi; \
	echo ""; \
	say_step "git submodules"; \
	submod_issues=0; \
	while IFS= read -r line; do \
		prefix="$${line:0:1}"; \
		mod_path="$${line#* }"; \
		mod_path="$${mod_path%% (*}"; \
		mod_path="$${mod_path## }"; \
		case "$$prefix" in \
			-) say_err "$$mod_path — not initialized"; submod_issues=$$((submod_issues + 1)) ;; \
			+) say_warn "$$mod_path — checked out but SHA differs from index" ;; \
		esac; \
	done < <(git -C "$(DOT_DIR)" submodule status 2>/dev/null); \
	if [ $$submod_issues -gt 0 ]; then \
		fails=$$((fails + submod_issues)); \
	else \
		say_ok "all submodules initialized"; \
	fi; \
	echo ""
	@vfails=0; \
	echo "── vendor health checks ──"; \
	echo ""; \
	$(MAKE) -C "$(VENDOR_VIM)"  doctor $(VENDOR_FLAGS) || vfails=$$((vfails + 1)); \
	echo ""; \
	$(MAKE) -C "$(VENDOR_OMZ)"  doctor $(VENDOR_FLAGS) || vfails=$$((vfails + 1)); \
	echo ""; \
	$(MAKE) -C "$(VENDOR_TMUX)" doctor $(VENDOR_FLAGS) || vfails=$$((vfails + 1)); \
	echo ""; \
	if [ $$vfails -gt 0 ]; then \
		echo "✘ $$vfails vendor doctor(s) reported issues"; \
		exit 1; \
	else \
		echo "✔ all vendor health checks passed"; \
	fi

# ══════════════════════════════════════════════════════════════════════════════
# CI / Verification targets
# ══════════════════════════════════════════════════════════════════════════════

.PHONY: dry-run-verify

dry-run-verify: ## Verify that DRY=1 produces zero mutations (for CI/pre-commit)
	@echo "🔍 Verifying dry-run idempotency..."
	@git status --short > /tmp/git-status-before.txt 2>&1 || true
	@echo "  Running: DRY=1 make vim-install"
	@DRY=1 make vim-install > /dev/null 2>&1
	@echo "  Running: DRY=1 make omz-sync-plugins"
	@DRY=1 make omz-sync-plugins > /dev/null 2>&1
	@echo "  Running: DRY=1 make tmux-install"
	@DRY=1 make tmux-install > /dev/null 2>&1
	@echo "  Running: DRY=1 make tmux-sync-plugins"
	@DRY=1 make tmux-sync-plugins > /dev/null 2>&1
	@echo "  Running: DRY=1 make omz-install"
	@DRY=1 make omz-install > /dev/null 2>&1
	@echo "  Running: DRY=1 make vim-build"
	@DRY=1 make vim-build > /dev/null 2>&1
	@git status --short > /tmp/git-status-after.txt 2>&1 || true
	@if diff -q /tmp/git-status-before.txt /tmp/git-status-after.txt > /dev/null 2>&1; then \
		echo "✅ PASS: All dry-run operations produced zero mutations"; \
		exit 0; \
	else \
		echo "❌ FAIL: Dry-run operations produced mutations:"; \
		echo "--- Before ---"; \
		cat /tmp/git-status-before.txt; \
		echo "--- After ---"; \
		cat /tmp/git-status-after.txt; \
		echo "--- Diff ---"; \
		diff /tmp/git-status-before.txt /tmp/git-status-after.txt || true; \
		exit 1; \
	fi

# ── Unit Tests ────────────────────────────────────────────────────────────────

.PHONY: test test-verbose test-module

test: ## Run all unit tests
	@zsh test/run_unit.sh

test-verbose: ## Run all unit tests with verbose TAP output
	@zsh test/run_unit.sh -v

test-module: ## Run a single test module (MODULE=name)
	@if [ -z "$(MODULE)" ]; then echo "Usage: make test-module MODULE=<filter>"; exit 1; fi
	@zsh test/run_unit.sh "$(MODULE)"
