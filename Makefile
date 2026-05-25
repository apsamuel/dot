# ──────────────────────────────────────────────────────────────────────────────
# ⚫️ dot Makefile — idempotent install orchestration & vendor management
#
# Usage:
#   make                              # print help
#   make dot-bootstrap                # full install (mirrors run)
#   DRY=1 make dot-bootstrap          # dry-run — prints planned actions, zero mutations
#   make check brew                   # ensure Homebrew is installed
#   make check deps                   # reconcile CLI + cask dependencies
#   make config zsh                   # configure zsh
#   make config shells                # group: zsh + bash
#   DEBUG=1 make config git           # enable xtrace for a single step
#   make vim plugin list              # vendor dispatch (vim)
#   make omz plugin sync              # vendor dispatch (oh-my-zsh)
#   make tmux status                  # vendor dispatch (oh-my-tmux)
#   make tmux plugin add PLUGIN=owner/repo   # add a tmux plugin
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
# Vendor parameters:
#   PLUGIN=owner/repo   for vim plugin add/rm, tmux plugin add/rm
#   BUNDLE=shared|nvim  for vim plugin add/rm
#   OWNER=<org>         for omz plugin add/rm, omz theme add/rm
#   REPO=<name>         for omz plugin add/rm, omz theme add/rm
#   EXEC=<cmd>          optional post-init command for omz plugin/theme add
#
# Requires: GNU Make 4.4+ (brew install make; use gnubin PATH)
# ──────────────────────────────────────────────────────────────────────────────

# ── Make version guard ────────────────────────────────────────────────────────
_MAKE_VER_MAJOR := $(word 1,$(subst ., ,$(MAKE_VERSION)))
_MAKE_VER_MINOR := $(word 2,$(subst ., ,$(MAKE_VERSION)))
_MAKE_VER_OK := $(shell [ $(_MAKE_VER_MAJOR) -gt 4 ] 2>/dev/null && echo y || { [ $(_MAKE_VER_MAJOR) -eq 4 ] && [ $(_MAKE_VER_MINOR) -ge 4 ] 2>/dev/null && echo y || echo n; })
ifneq ($(_MAKE_VER_OK),y)
$(error GNU Make 4.4+ required (found $(MAKE_VERSION)). Install: brew install make && add $$(brew --prefix)/opt/make/libexec/gnubin to PATH)
endif

# ── Shell & .ONESHELL ─────────────────────────────────────────────────────────
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
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

# Shared env propagation for all vendor sub-makes.
VENDOR_FLAGS := DRY="$(DRY)" DEBUG="$(DEBUG)" VERBOSE="$(VERBOSE)" DOT_DRY_RUN="$(DRY)" DOT_DEBUG="$(DEBUG)" DOT_VERBOSE="$(VERBOSE)"

# ── Dispatch infrastructure ────────────────────────────────────────────────────
# Enables space-separated sub-commands for top-level dispatch targets:
#   make vim plugin list, make check brew, make config zsh, etc.
# The dispatch target must be the FIRST word in MAKECMDGOALS. Everything after it
# forms the sub-command string dispatched via case in the target recipe.
# Extra words are defined as no-op targets via $(eval) so Make doesn't error.
_DISPATCH := vim omz tmux check config
_ACTIVE_TARGET := $(firstword $(filter $(_DISPATCH),$(MAKECMDGOALS)))

ifneq ($(_ACTIVE_TARGET),)
  _SUBCMD := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  ifneq ($(_SUBCMD),)
    # Only create no-ops for words that aren't real dispatch targets (those
    # have their own recipes and will bail out via a guard instead).
    _NOOP_WORDS := $(filter-out $(_DISPATCH),$(_SUBCMD))
    ifneq ($(_NOOP_WORDS),)
      $(foreach _w,$(_NOOP_WORDS),$(eval $(_w):;@:))
    endif
  endif
endif

# ── Phony declarations ────────────────────────────────────────────────────────
.PHONY: help \
        preflight init-submodules \
        check config \
        vim omz tmux \
        dot-bootstrap \
        doctor dry-run-verify \
        test test-verbose test-module

# ══════════════════════════════════════════════════════════════════════════════
# Help
# ══════════════════════════════════════════════════════════════════════════════

define _BOOT
export DOT_DRY_RUN="$(DRY)" DOT_DEPS="$(DEPS)" DOT_INSTALL_LANG_DEPS="$(LANG_DEPS)" DOT_DIRECTORY="$(DOT_DIR)"
source "$(BOOTSTRAP)"
if [[ "$(DEBUG)" == "1" ]]; then set -x; fi
endef

help: ## Show this help
	@echo "⚫️  dot — install orchestration & vendor management"
	@echo ""
	@echo "Usage:  [PARAMS] make <target> [sub-command...]"
	@echo ""
	@echo "Parameters (env vars):"
	@echo "  DRY=1         dry-run mode (no filesystem mutations)"
	@echo "  DEBUG=1       enable xtrace"
	@echo "  VERBOSE=1     enable verbose vendor output"
	@echo "  DEPS=1        force reinstall brew bundle"
	@echo "  LANG_DEPS=1   install pip/npm packages"
	@echo ""
	@echo "Vendor parameters:"
	@echo "  PLUGIN=owner/repo   vim/tmux plugin add/rm"
	@echo "  BUNDLE=shared|nvim  vim plugin add/rm"
	@echo "  OWNER=<org>         omz plugin/theme add/rm"
	@echo "  REPO=<name>         omz plugin/theme add/rm"
	@echo "  EXEC=<cmd>          omz plugin/theme add post-init command"
	@echo ""
	@echo "Install targets:"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-24s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "Check dispatch (make check <command>):"
	@printf "  \033[36mmake check brew\033[0m               ensure Homebrew is installed\n"
	@printf "  \033[36mmake check deps\033[0m               reconcile CLI + cask dependencies\n"
	@printf "  \033[36mmake check cloud\033[0m              verify iCloud Drive and link ~/iCloud\n"
	@printf "  \033[36mmake check p10k\033[0m               verify p10k config symlink\n"
	@printf "  \033[36mmake check omz\033[0m                ensure oh-my-zsh is installed/linked\n"
	@printf "  \033[36mmake check omtmux\033[0m             verify oh-my-tmux config + tpm plugins\n"
	@echo ""
	@echo "Config dispatch (make config <command>):"
	@printf "  \033[36mmake config zsh\033[0m               configure zsh (link zshrc, set shell)\n"
	@printf "  \033[36mmake config bash\033[0m              configure bash (link bashrc)\n"
	@printf "  \033[36mmake config ssh\033[0m               link SSH config + keys from iCloud\n"
	@printf "  \033[36mmake config git\033[0m               link gitconfig from iCloud\n"
	@printf "  \033[36mmake config xdg\033[0m               link iCloud configs into XDG_CONFIG_HOME\n"
	@printf "  \033[36mmake config gh\033[0m                link gh CLI config from iCloud\n"
	@printf "  \033[36mmake config python\033[0m            provision Python venv (uv)\n"
	@printf "  \033[36mmake config node\033[0m              provision Node via n\n"
	@printf "  \033[36mmake config iterm\033[0m             configure iTerm2\n"
	@printf "  \033[36mmake config figlet\033[0m            verify figlet fonts (vendored)\n"
	@printf "  \033[36mmake config fonts\033[0m             install fonts from iCloud\n"
	@printf "  \033[36mmake config p10k\033[0m              configure Powerlevel10k\n"
	@printf "  \033[36mmake config vim\033[0m               configure vim + neovim\n"
	@printf "  \033[36mmake config tmux\033[0m              configure oh-my-tmux + tpm plugins\n"
	@printf "  \033[36mmake config omz\033[0m               sync oh-my-zsh custom plugins\n"
	@printf "  \033[36mmake config shells\033[0m            group: zsh + bash\n"
	@printf "  \033[36mmake config configs\033[0m           group: ssh + git + gh\n"
	@printf "  \033[36mmake config langs\033[0m             group: python + node\n"
	@echo ""
	@echo "Vendor dispatch (space-separated sub-commands):"
	@printf "  \033[36mmake vim install\033[0m              symlinks + submodules + build\n"
	@printf "  \033[36mmake vim doctor\033[0m               plugin-status + :checkhealth\n"
	@printf "  \033[36mmake vim build\033[0m                compile native artifacts\n"
	@printf "  \033[36mmake vim update\033[0m               pull latest, rebuild\n"
	@printf "  \033[36mmake vim helptags\033[0m             regenerate helptags\n"
	@printf "  \033[36mmake vim clean\033[0m                remove symlinks\n"
	@printf "  \033[36mmake vim plugin list\033[0m          list vendored plugins\n"
	@printf "  \033[36mmake vim plugin add\033[0m           PLUGIN=owner/repo BUNDLE=shared|nvim\n"
	@printf "  \033[36mmake vim plugin rm\033[0m            PLUGIN=name BUNDLE=shared|nvim\n"
	@echo ""
	@printf "  \033[36mmake omz install\033[0m              init & update all submodules\n"
	@printf "  \033[36mmake omz doctor\033[0m               health check\n"
	@printf "  \033[36mmake omz plugin list\033[0m          list custom plugins\n"
	@printf "  \033[36mmake omz plugin add\033[0m           OWNER=org REPO=name [EXEC=cmd]\n"
	@printf "  \033[36mmake omz plugin rm\033[0m            OWNER=org REPO=name\n"
	@printf "  \033[36mmake omz plugin sync\033[0m          reconcile from data file\n"
	@printf "  \033[36mmake omz theme add\033[0m            OWNER=org REPO=name [EXEC=cmd]\n"
	@printf "  \033[36mmake omz theme rm\033[0m             OWNER=org REPO=name\n"
	@printf "  \033[36mmake omz theme sync\033[0m           reconcile from data file\n"
	@echo ""
	@printf "  \033[36mmake tmux install\033[0m             link configs + sync plugins\n"
	@printf "  \033[36mmake tmux doctor\033[0m              health check\n"
	@printf "  \033[36mmake tmux clean\033[0m               remove config symlinks\n"
	@printf "  \033[36mmake tmux update\033[0m              update plugin submodules\n"
	@printf "  \033[36mmake tmux status\033[0m              config health + plugin status\n"
	@printf "  \033[36mmake tmux plugin list\033[0m         declared vs installed\n"
	@printf "  \033[36mmake tmux plugin add\033[0m          PLUGIN=owner/repo\n"
	@printf "  \033[36mmake tmux plugin rm\033[0m           PLUGIN=owner/repo\n"
	@printf "  \033[36mmake tmux plugin sync\033[0m         reconcile declared \xe2\x86\x94 on-disk\n"
	@echo ""
	@echo "Examples:"
	@echo "  make dot-bootstrap                    # full install"
	@echo "  DRY=1 make dot-bootstrap              # plan everything, change nothing"
	@echo "  make check brew                       # verify Homebrew"
	@echo "  make config zsh                       # configure zsh"
	@echo "  make config shells                    # configure zsh + bash"
	@echo "  make vim plugin list                  # list vendored vim plugins"
	@echo "  make omz plugin sync                  # reconcile oh-my-zsh plugins"
	@echo "  make tmux status                      # check tmux config health"
	@echo "  make doctor                           # read-only system health check"

# ══════════════════════════════════════════════════════════════════════════════
# Install targets (pipeline order matches run)
# ══════════════════════════════════════════════════════════════════════════════

preflight: ## Preflight checks (arch, os, tools)
	$(_BOOT)
	preflight

init-submodules: ## Initialize git submodules
	$(_BOOT)
	init_submodules

# ══════════════════════════════════════════════════════════════════════════════
# Check dispatch — make check <command>
#
# Sub-commands:
#   brew, deps, cloud, p10k, omz, omtmux
# ══════════════════════════════════════════════════════════════════════════════

check: ## Dispatch: make check <command>
	if [ "$(_ACTIVE_TARGET)" != "check" ]; then exit 0; fi
	$(_BOOT)
	subcmd="$(_SUBCMD)"
	case "$$subcmd" in
		brew)
			check_brew ;;
		deps)
			check_deps
			check_cask_deps ;;
		cloud)
			check_cloud ;;
		p10k)
			check_p10k ;;
		omz)
			check_omz ;;
		omtmux|tmux)
			check_omtmux ;;
		"")
			echo "Usage: make check <command>"
			echo ""
			echo "Commands:"
			echo "  brew       ensure Homebrew is installed"
			echo "  deps       reconcile CLI + cask dependencies"
			echo "  cloud      verify iCloud Drive and link ~/iCloud"
			echo "  p10k       verify p10k config symlink"
			echo "  omz        ensure oh-my-zsh is installed and linked"
			echo "  omtmux     verify oh-my-tmux config + tpm plugins"
			exit 1 ;;
		*)
			echo "Unknown command: make check $$subcmd"
			echo ""
			echo "Available: brew, deps, cloud, p10k, omz, omtmux"
			exit 1 ;;
	esac

# ══════════════════════════════════════════════════════════════════════════════
# Config dispatch — make config <command>
#
# Sub-commands:
#   zsh, bash, ssh, git, xdg, gh, python, node,
#   iterm, figlet, fonts, p10k, vim, tmux, omz
# Groups:
#   shells (zsh + bash), configs (ssh + git + gh), langs (python + node)
# ══════════════════════════════════════════════════════════════════════════════

config: ## Dispatch: make config <command>
	if [ "$(_ACTIVE_TARGET)" != "config" ]; then exit 0; fi
	$(_BOOT)
	subcmd="$(_SUBCMD)"
	case "$$subcmd" in
		zsh)
			config_zsh ;;
		bash)
			config_bash ;;
		ssh)
			check_cloud && config_ssh ;;
		git)
			check_cloud && config_git ;;
		xdg)
			check_cloud && config_xdg ;;
		gh)
			check_cloud && config_xdg gh ;;
		python)
			config_python ;;
		node)
			config_node ;;
		iterm)
			config_iterm ;;
		figlet)
			config_figlet ;;
		fonts)
			check_cloud && install_fonts ;;
		p10k)
			check_cloud && config_p10k ;;
		vim)
			$(MAKE) -C "$(VENDOR_VIM)" install $(VENDOR_FLAGS) ;;
		tmux)
			$(MAKE) -C "$(VENDOR_TMUX)" install $(VENDOR_FLAGS) ;;
		omz)
			$(MAKE) -C "$(VENDOR_OMZ)" sync-plugins $(VENDOR_FLAGS) ;;
		shells)
			config_zsh
			config_bash ;;
		configs)
			check_cloud && config_ssh
			check_cloud && config_git
			check_cloud && config_xdg gh ;;
		langs)
			config_python
			config_node ;;
		"")
			echo "Usage: make config <command>"
			echo ""
			echo "Commands:"
			echo "  zsh        configure zsh (link zshrc, set login shell)"
			echo "  bash       configure bash (link bashrc)"
			echo "  ssh        link SSH config + keys from iCloud"
			echo "  git        link gitconfig from iCloud"
			echo "  xdg        link iCloud configs into XDG_CONFIG_HOME"
			echo "  gh         link gh CLI config from iCloud"
			echo "  python     provision Python venv (uv)"
			echo "  node       provision Node via n"
			echo "  iterm      configure iTerm2"
			echo "  figlet     verify figlet fonts (vendored)"
			echo "  fonts      install fonts from iCloud"
			echo "  p10k       configure Powerlevel10k"
			echo "  vim        configure vim + neovim (vendor install)"
			echo "  tmux       configure oh-my-tmux + tpm plugins"
			echo "  omz        sync oh-my-zsh custom plugins"
			echo ""
			echo "Groups:"
			echo "  shells     zsh + bash"
			echo "  configs    ssh + git + gh"
			echo "  langs      python + node"
			exit 1 ;;
		*)
			echo "Unknown command: make config $$subcmd"
			echo ""
			echo "Available: zsh, bash, ssh, git, xdg, gh, python, node,"
			echo "           iterm, figlet, fonts, p10k, vim, tmux, omz,"
			echo "           shells, configs, langs"
			exit 1 ;;
	esac

# ══════════════════════════════════════════════════════════════════════════════
# Full install (mirrors run pipeline)
# ══════════════════════════════════════════════════════════════════════════════

dot-bootstrap: ## Full install (all steps, fails fast)
	$(_BOOT)
	print_banner
	preflight
	run

# ══════════════════════════════════════════════════════════════════════════════
# Vendor dispatch — vim  (make vim <sub-command>)
#
# Sub-commands:
#   install, doctor, build, update, helptags, clean, plugins
#   plugin list | plugin add | plugin rm
# ══════════════════════════════════════════════════════════════════════════════

vim: ## Vendor dispatch: make vim <command> [plugin <action>]
	if [ "$(_ACTIVE_TARGET)" != "vim" ]; then exit 0; fi
	subcmd="$(_SUBCMD)"
	case "$$subcmd" in
		install)
			$(MAKE) -C "$(VENDOR_VIM)" install $(VENDOR_FLAGS) ;;
		doctor)
			$(MAKE) -C "$(VENDOR_VIM)" doctor $(VENDOR_FLAGS) ;;
		build)
			$(MAKE) -C "$(VENDOR_VIM)" build $(VENDOR_FLAGS) ;;
		update)
			$(MAKE) -C "$(VENDOR_VIM)" update $(VENDOR_FLAGS) ;;
		helptags)
			$(MAKE) -C "$(VENDOR_VIM)" helptags $(VENDOR_FLAGS) ;;
		clean)
			$(MAKE) -C "$(VENDOR_VIM)" clean $(VENDOR_FLAGS) ;;
		plugins)
			$(MAKE) -C "$(VENDOR_VIM)" plugins $(VENDOR_FLAGS) ;;
		"plugin list")
			$(MAKE) -C "$(VENDOR_VIM)" list $(VENDOR_FLAGS) ;;
		"plugin add")
			$(MAKE) -C "$(VENDOR_VIM)" add PLUGIN="$(PLUGIN)" BUNDLE="$(BUNDLE)" $(VENDOR_FLAGS) ;;
		"plugin rm")
			$(MAKE) -C "$(VENDOR_VIM)" rm PLUGIN="$(PLUGIN)" BUNDLE="$(BUNDLE)" $(VENDOR_FLAGS) ;;
		"")
			echo "Usage: make vim <command>"
			echo ""
			echo "Commands:"
			echo "  install        symlinks + submodules + build"
			echo "  doctor         plugin-status + :checkhealth"
			echo "  build          compile native artifacts"
			echo "  update         pull latest submodules, rebuild"
			echo "  helptags       regenerate vim/nvim helptags"
			echo "  clean          remove ~/.vim and ~/.config/nvim symlinks"
			echo "  plugins        show staged plugins per editor"
			echo "  plugin list    list vendored plugins"
			echo "  plugin add     vendor a new plugin (PLUGIN=owner/repo BUNDLE=shared|nvim)"
			echo "  plugin rm      remove a vendored plugin (PLUGIN=name BUNDLE=shared|nvim)"
			exit 1 ;;
		*)
			echo "Unknown command: make vim $$subcmd"
			echo ""
			echo "Available: install, doctor, build, update, helptags, clean, plugins,"
			echo "           plugin list, plugin add, plugin rm"
			exit 1 ;;
	esac

# ══════════════════════════════════════════════════════════════════════════════
# Vendor dispatch — omz  (make omz <sub-command>)
#
# Sub-commands:
#   install, doctor
#   plugin list | plugin add | plugin rm | plugin sync
#   theme add | theme rm | theme sync
# ══════════════════════════════════════════════════════════════════════════════

omz: ## Vendor dispatch: make omz <command> [plugin|theme <action>]
	if [ "$(_ACTIVE_TARGET)" != "omz" ]; then exit 0; fi
	subcmd="$(_SUBCMD)"
	case "$$subcmd" in
		install)
			$(MAKE) -C "$(VENDOR_OMZ)" install $(VENDOR_FLAGS) ;;
		doctor)
			$(MAKE) -C "$(VENDOR_OMZ)" doctor $(VENDOR_FLAGS) ;;
		"plugin list")
			$(MAKE) -C "$(VENDOR_OMZ)" list-plugins $(VENDOR_FLAGS) ;;
		"plugin add")
			$(MAKE) -C "$(VENDOR_OMZ)" add-plugin OWNER="$(OWNER)" REPO="$(REPO)" EXEC="$(EXEC)" $(VENDOR_FLAGS) ;;
		"plugin rm")
			$(MAKE) -C "$(VENDOR_OMZ)" remove-plugin OWNER="$(OWNER)" REPO="$(REPO)" $(VENDOR_FLAGS) ;;
		"plugin sync")
			$(MAKE) -C "$(VENDOR_OMZ)" sync-plugins $(VENDOR_FLAGS) ;;
		"theme add")
			$(MAKE) -C "$(VENDOR_OMZ)" add-theme OWNER="$(OWNER)" REPO="$(REPO)" EXEC="$(EXEC)" $(VENDOR_FLAGS) ;;
		"theme rm")
			$(MAKE) -C "$(VENDOR_OMZ)" remove-theme OWNER="$(OWNER)" REPO="$(REPO)" $(VENDOR_FLAGS) ;;
		"theme sync")
			$(MAKE) -C "$(VENDOR_OMZ)" sync-themes $(VENDOR_FLAGS) ;;
		"")
			echo "Usage: make omz <command>"
			echo ""
			echo "Commands:"
			echo "  install        init & update all submodules"
			echo "  doctor         read-only health check"
			echo "  plugin list    list custom plugins"
			echo "  plugin add     add a plugin (OWNER=org REPO=name [EXEC=cmd])"
			echo "  plugin rm      remove a plugin (OWNER=org REPO=name)"
			echo "  plugin sync    reconcile plugins from data file"
			echo "  theme add      add a theme (OWNER=org REPO=name [EXEC=cmd])"
			echo "  theme rm       remove a theme (OWNER=org REPO=name)"
			echo "  theme sync     reconcile themes from data file"
			exit 1 ;;
		*)
			echo "Unknown command: make omz $$subcmd"
			echo ""
			echo "Available: install, doctor,"
			echo "           plugin list, plugin add, plugin rm, plugin sync,"
			echo "           theme add, theme rm, theme sync"
			exit 1 ;;
	esac

# ══════════════════════════════════════════════════════════════════════════════
# Vendor dispatch — tmux  (make tmux <sub-command>)
#
# Sub-commands:
#   install, doctor, clean, update, status
#   plugin list | plugin add | plugin rm | plugin sync
# ══════════════════════════════════════════════════════════════════════════════

tmux: ## Vendor dispatch: make tmux <command> [plugin <action>]
	if [ "$(_ACTIVE_TARGET)" != "tmux" ]; then exit 0; fi
	subcmd="$(_SUBCMD)"
	case "$$subcmd" in
		install)
			$(MAKE) -C "$(VENDOR_TMUX)" install $(VENDOR_FLAGS) ;;
		doctor)
			$(MAKE) -C "$(VENDOR_TMUX)" doctor $(VENDOR_FLAGS) ;;
		clean)
			$(MAKE) -C "$(VENDOR_TMUX)" clean $(VENDOR_FLAGS) ;;
		update)
			$(MAKE) -C "$(VENDOR_TMUX)" update $(VENDOR_FLAGS) ;;
		status)
			$(MAKE) -C "$(VENDOR_TMUX)" status $(VENDOR_FLAGS) ;;
		"plugin list")
			$(MAKE) -C "$(VENDOR_TMUX)" list-plugins $(VENDOR_FLAGS) ;;
		"plugin add")
			$(MAKE) -C "$(VENDOR_TMUX)" add-plugin PLUGIN="$(PLUGIN)" $(VENDOR_FLAGS) ;;
		"plugin rm")
			$(MAKE) -C "$(VENDOR_TMUX)" remove-plugin PLUGIN="$(PLUGIN)" $(VENDOR_FLAGS) ;;
		"plugin sync")
			$(MAKE) -C "$(VENDOR_TMUX)" sync-plugins $(VENDOR_FLAGS) ;;
		"")
			echo "Usage: make tmux <command>"
			echo ""
			echo "Commands:"
			echo "  install        link configs + sync plugin submodules"
			echo "  doctor         read-only health check"
			echo "  clean          remove config symlinks"
			echo "  update         update declared plugin submodules"
			echo "  status         config health + plugin status"
			echo "  plugin list    show declared vs installed"
			echo "  plugin add     declare + clone plugin (PLUGIN=owner/repo)"
			echo "  plugin rm      undeclare + remove plugin (PLUGIN=owner/repo)"
			echo "  plugin sync    reconcile declared ↔ on-disk"
			exit 1 ;;
		*)
			echo "Unknown command: make tmux $$subcmd"
			echo ""
			echo "Available: install, doctor, clean, update, status,"
			echo "           plugin list, plugin add, plugin rm, plugin sync"
			exit 1 ;;
	esac

# ══════════════════════════════════════════════════════════════════════════════
# Doctor — non-mutating health check
# ══════════════════════════════════════════════════════════════════════════════

doctor: ## Non-mutating health check: deps, symlinks, submodules, vendors
	$(_BOOT)
	fails=0
	echo ""
	say_step "dot doctor"
	echo ""
	say_step "tier-0 dependencies"
	if "$(DOT_DIR)/scripts/dot-deps-report.sh" --tier 0 -q; then
		say_ok "all tier-0 dependencies present"
	else
		say_err "tier-0 dependency check failed"
		fails=$$((fails + 1))
	fi
	echo ""
	say_step "core symlinks"
	for pair in "$$HOME/.zshrc:$(DOT_DIR)/zshrc" "$$HOME/.oh-my-zsh:$(VENDOR_OMZ)"; do
		link="$${pair%%:*}"; expected="$${pair#*:}"
		if [ -L "$$link" ]; then
			target=$$(readlink "$$link")
			if [ "$$target" = "$$expected" ]; then
				say_ok "$$link → $$target"
			else
				say_err "$$link → $$target (expected $$expected)"
				fails=$$((fails + 1))
			fi
		elif [ -e "$$link" ]; then
			say_err "$$link exists but is NOT a symlink"
			fails=$$((fails + 1))
		else
			say_err "$$link missing"
			fails=$$((fails + 1))
		fi
	done
	if [ -d "$$HOME/iCloud" ]; then
		say_ok "~/iCloud exists"
	else
		say_warn "~/iCloud not found (optional)"
	fi
	echo ""
	say_step "git submodules"
	submod_issues=0
	while IFS= read -r line; do
		prefix="$${line:0:1}"
		mod_path="$${line#* }"
		mod_path="$${mod_path%% (*}"
		mod_path="$${mod_path## }"
		case "$$prefix" in
			-) say_err "$$mod_path — not initialized"; submod_issues=$$((submod_issues + 1)) ;;
			+) say_warn "$$mod_path — checked out but SHA differs from index" ;;
		esac
	done < <(git -C "$(DOT_DIR)" submodule status 2>/dev/null)
	if [ $$submod_issues -gt 0 ]; then
		fails=$$((fails + submod_issues))
	else
		say_ok "all submodules initialized"
	fi
	echo ""
	echo "── vendor health checks ──"
	echo ""
	vfails=0
	$(MAKE) -C "$(VENDOR_VIM)"  doctor $(VENDOR_FLAGS) || vfails=$$((vfails + 1))
	echo ""
	$(MAKE) -C "$(VENDOR_OMZ)"  doctor $(VENDOR_FLAGS) || vfails=$$((vfails + 1))
	echo ""
	$(MAKE) -C "$(VENDOR_TMUX)" doctor $(VENDOR_FLAGS) || vfails=$$((vfails + 1))
	echo ""
	if [ $$vfails -gt 0 ]; then
		echo "✘ $$vfails vendor doctor(s) reported issues"
		exit 1
	else
		echo "✔ all vendor health checks passed"
	fi

# ══════════════════════════════════════════════════════════════════════════════
# CI / Verification targets
# ══════════════════════════════════════════════════════════════════════════════

dry-run-verify: ## Verify that DRY=1 produces zero mutations (for CI/pre-commit)
	echo "🔍 Verifying dry-run idempotency..."
	git status --short > /tmp/git-status-before.txt 2>&1 || true
	echo "  Running: DRY=1 make vim install"
	DRY=1 $(MAKE) vim install > /dev/null 2>&1
	echo "  Running: DRY=1 make omz plugin sync"
	DRY=1 $(MAKE) omz plugin sync > /dev/null 2>&1
	echo "  Running: DRY=1 make tmux install"
	DRY=1 $(MAKE) tmux install > /dev/null 2>&1
	echo "  Running: DRY=1 make tmux plugin sync"
	DRY=1 $(MAKE) tmux plugin sync > /dev/null 2>&1
	echo "  Running: DRY=1 make omz install"
	DRY=1 $(MAKE) omz install > /dev/null 2>&1
	echo "  Running: DRY=1 make vim build"
	DRY=1 $(MAKE) vim build > /dev/null 2>&1
	git status --short > /tmp/git-status-after.txt 2>&1 || true
	if diff -q /tmp/git-status-before.txt /tmp/git-status-after.txt > /dev/null 2>&1; then
		echo "✅ PASS: All dry-run operations produced zero mutations"
		exit 0
	else
		echo "❌ FAIL: Dry-run operations produced mutations:"
		echo "--- Before ---"
		cat /tmp/git-status-before.txt
		echo "--- After ---"
		cat /tmp/git-status-after.txt
		echo "--- Diff ---"
		diff /tmp/git-status-before.txt /tmp/git-status-after.txt || true
		exit 1
	fi

# ── Unit Tests ────────────────────────────────────────────────────────────────

test: ## Run all unit tests
	zsh test/run_unit.sh

test-verbose: ## Run all unit tests with verbose TAP output
	zsh test/run_unit.sh -v

test-module: ## Run a single test module (MODULE=name)
	if [ -z "$(MODULE)" ]; then echo "Usage: make test-module MODULE=<filter>"; exit 1; fi
	zsh test/run_unit.sh "$(MODULE)"
