#!/usr/bin/env zsh
# Test: modules/000-a-base.sh — env var exports
source "${0:A:h}/../framework.sh"
source "${0:A:h}/../mocks/env.sh"
source "${0:A:h}/../mocks/tools.sh"

# Source the module under test
source_module "000-a-base.sh"

# ── Tests ─────────────────────────────────────────────────────────────────────

describe "000-a-base.sh: history variables"

test_histsize_set() {
    assert_defined "HISTSIZE"
}

test_histfile_set() {
    assert_defined "HISTFILE"
}

test_savehist_set() {
    assert_defined "SAVEHIST"
}

it "HISTSIZE is defined" test_histsize_set
it "HISTFILE is defined" test_histfile_set
it "SAVEHIST is defined" test_savehist_set

describe "000-a-base.sh: locale and editor"

test_lang_exported() {
    assert_eq "en_US.UTF-8" "${LANG}"
}

test_editor_exported() {
    assert_eq "vim" "${EDITOR}"
}

it "LANG is en_US.UTF-8" test_lang_exported
it "EDITOR is vim" test_editor_exported

describe "000-a-base.sh: ZSH paths"

test_zsh_var() {
    assert_defined "ZSH"
}

test_zsh_custom_var() {
    assert_defined "ZSH_CUSTOM"
}

test_zsh_custom_is_subdir() {
    assert_contains "${ZSH_CUSTOM}" "${ZSH}"
}

it "ZSH is defined" test_zsh_var
it "ZSH_CUSTOM is defined" test_zsh_custom_var
it "ZSH_CUSTOM is under ZSH" test_zsh_custom_is_subdir

describe "000-a-base.sh: iCloud paths"

test_icloud_defined() {
    assert_defined "ICLOUD"
}

test_icloud_documents() {
    assert_defined "ICLOUD_DOCUMENTS"
}

test_icloud_screenshots() {
    assert_defined "ICLOUD_SCREENSHOTS"
}

it "ICLOUD is defined" test_icloud_defined
it "ICLOUD_DOCUMENTS is defined" test_icloud_documents
it "ICLOUD_SCREENSHOTS is defined" test_icloud_screenshots

describe "000-a-base.sh: XDG directories"

test_xdg_cache() {
    assert_defined "XDG_CACHE_HOME"
}

test_xdg_config() {
    assert_defined "XDG_CONFIG_HOME"
}

test_xdg_data() {
    assert_defined "XDG_DATA_HOME"
}

it "XDG_CACHE_HOME is defined" test_xdg_cache
it "XDG_CONFIG_HOME is defined" test_xdg_config
it "XDG_DATA_HOME is defined" test_xdg_data

describe "000-a-base.sh: system information"

test_cpu_brand() {
    assert_defined "CPU_BRAND"
}

test_cpu_cores() {
    assert_defined "CPU_CORES"
}

test_operating_system() {
    assert_defined "OPERATING_SYSTEM"
}

test_cpu_architecture() {
    assert_defined "CPU_ARCHITECTURE"
}

it "CPU_BRAND is defined" test_cpu_brand
it "CPU_CORES is defined" test_cpu_cores
it "OPERATING_SYSTEM is defined" test_operating_system
it "CPU_ARCHITECTURE is defined" test_cpu_architecture

describe "000-a-base.sh: shell versions"

test_zsh_release() {
    assert_defined "ZSH_RELEASE"
}

test_git_release() {
    assert_defined "GIT_RELEASE"
}

it "ZSH_RELEASE is defined" test_zsh_release
it "GIT_RELEASE is defined" test_git_release

tap_summary
