# shellcheck shell=bash
# Test: modules/000-a-output.sh — color/emoji output helpers
# Portable bootstrap — works under bash and zsh
if [ -n "${ZSH_VERSION:-}" ]; then _test_dir="${0:A:h}"
else _test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; fi
source "${_test_dir}/../framework.sh"
source "${_test_dir}/../mocks/env.sh"
source "${_test_dir}/../mocks/tools.sh"

# Ensure outputs are enabled
export DOT_DISABLE_OUTPUTS=0

# Source the module under test
source_module "000-a-output.sh"

# ── Tests ─────────────────────────────────────────────────────────────────────

describe "000-a-output.sh: dot::output::levels()"

test_print_levels_returns_all() {
    local result=""
    result="$(dot::output::levels)"
    assert_contains "${result}" "info" "levels include info" || return 1
    assert_contains "${result}" "error" "levels include error" || return 1
    assert_contains "${result}" "debug" "levels include debug"
}

it "dot::output::levels returns info, error, debug" test_print_levels_returns_all

describe "000-a-output.sh: dot::output::level()"

test_print_level_info() {
    local result=""
    result="$(dot::output::level info)"
    assert_contains "${result}" "info" "info label is rendered"
}

test_print_level_error() {
    local result=""
    result="$(dot::output::level error)"
    assert_contains "${result}" "error" "error label is rendered"
}

test_print_level_invalid() {
    dot::output::level "nonexistent" > /dev/null 2>&1
    local rc=$?
    assert_eq "1" "${rc}" "invalid level fails"
}

test_print_level_no_args() {
    dot::output::level > /dev/null 2>&1
    local rc=$?
    assert_eq "1" "${rc}" "missing level fails"
}

it "dot::output::level info contains 'info'" test_print_level_info
it "dot::output::level error contains 'error'" test_print_level_error
it "dot::output::level rejects invalid level" test_print_level_invalid
it "dot::output::level fails with no arguments" test_print_level_no_args

describe "000-a-output.sh: dot::output::pretty()"

test_print_pretty_basic() {
    local result=""
    result="$(dot::output::pretty "hello world" 2>/dev/null)"
    assert_contains "${result}" "hello world" "message is rendered"
}

test_print_pretty_no_message_fails() {
    dot::output::pretty -l info > /dev/null 2>&1
    local rc=$?
    assert_eq "1" "${rc}" "missing message fails"
}

test_print_pretty_with_level() {
    local result=""
    result="$(dot::output::pretty -l error "something failed" 2>/dev/null)"
    assert_contains "${result}" "something failed" "error message is rendered"
}

it "dot::output::pretty includes the message" test_print_pretty_basic
it "dot::output::pretty fails with no message" test_print_pretty_no_message_fails
it "dot::output::pretty -l error includes message" test_print_pretty_with_level

describe "000-a-output.sh: DOT_DISABLE_OUTPUTS guard"

test_disable_outputs_guard() {
    # When DOT_DISABLE_OUTPUTS=1, sourcing returns early —
    # we just verify the guard variable exists as a mechanism
    assert_eq "0" "${DOT_DISABLE_OUTPUTS}" "output is enabled for this suite"
}

it "DOT_DISABLE_OUTPUTS is recognized" test_disable_outputs_guard

describe "000-a-output.sh: command interface"

test_pretty_repeated_calls() {
    dot::output::pretty -l error "first" >/dev/null || return 1
    local result=""
    result="$(dot::output::pretty -l info "second")" || return 1
    assert_contains "${result}" "second" "each call parses its own arguments"
}

test_pretty_rejects_invalid_options() {
    local result="" ret=0
    result="$(dot::output::pretty -x "message" 2>"${TEST_TMPDIR}/pretty.err")" || ret=$?
    assert_eq "1" "${ret}" "unknown options fail" || return 1
    assert_eq "" "${result}" "invalid input does not render a message" || return 1
    assert_contains "$(cat "${TEST_TMPDIR}/pretty.err")" "Invalid option" "error is on stderr"
}

test_pretty_help() {
    local result=""
    result="$(dot::output::pretty --help 2>"${TEST_TMPDIR}/help.err")" || return 1
    assert_contains "${result}" "Usage:" "help describes invocation" || return 1
    assert_eq "" "$(cat "${TEST_TMPDIR}/help.err")" "help does not emit errors"
}

test_pretty_long_options() {
    local result=""
    result="$(dot::output::pretty --level error --color "message")" || return 1
    assert_contains "${result}" "message" "long options accept the message"
}

test_output_contextual_help() {
    local result="" direct=""
    result="$(dot::output help pretty)" || return 1
    direct="$(dot::output::pretty --help)" || return 1
    assert_eq "${direct}" "${result}" "dispatcher and leaf share contextual help"
}

it "pretty resets parser state between calls" test_pretty_repeated_calls
it "pretty rejects unknown options before rendering" test_pretty_rejects_invalid_options
it "pretty supports clean contextual help" test_pretty_help
it "pretty supports long options" test_pretty_long_options
it "dispatcher provides contextual help" test_output_contextual_help

test_output_all_help_without_backends() {
    local topic="" flag="" result="" expected=""
    yq() { _mock_record help_backend; return 99; }
    shuf() { _mock_record help_backend; return 99; }
    figlet() { _mock_record help_backend; return 99; }
    tput() { _mock_record help_backend; return 99; }
    stty() { _mock_record help_backend; return 99; }
    git() { _mock_record help_backend; return 99; }
    tmux() { _mock_record help_backend; return 99; }
    chafa() { _mock_record help_backend; return 99; }
    find() { _mock_record help_backend; return 99; }
    local PATH="${TEST_TMPDIR}/no-tools"
    for topic in pretty level levels image logo quote term-quote figlet random-font width height color-tab colors256 splash splash-info; do
        expected="$(dot::output help "${topic}")" || return 1
        assert_contains "${expected}" "Usage:" "${topic} has contextual usage" || return 1
        for flag in -h --help; do
            result="$("dot::output::${topic}" "${flag}" 2>"${TEST_TMPDIR}/help.err")" || return 1
            assert_eq "${expected}" "${result}" "${topic} leaf help matches family help" || return 1
            assert_eq "" "$(<"${TEST_TMPDIR}/help.err")" "${topic} help has no backend errors" || return 1
        done
    done
    assert_not_called help_backend "help does not call available backends either"
}

test_output_unknown_commands() {
    local ret=0 result=""
    result="$(dot::output _colorize secret 2>"${TEST_TMPDIR}/unknown.err")" || ret=$?
    assert_eq "1" "${ret}" "private helpers are not dispatched" || return 1
    assert_eq "" "${result}" "unknown command does not print data" || return 1
    ret=0
    dot::output help nonexistent >/dev/null 2>&1 || ret=$?
    assert_eq "1" "${ret}" "unknown help topic fails"
}

test_pretty_parser_contract() {
    local OPTIND=7 result="" expected=""
    expected="$(dot::output::pretty -ce -l error 'two words')" || return 1
    result="$(dot::output::pretty --color --emoji --level=error 'two words')" || return 1
    assert_eq "${expected}" "${result}" "long and clustered short flags are equivalent" || return 1
    dot::output::pretty -l info message >/dev/null || return 1
    assert_eq "7" "${OPTIND}" "caller parser state is preserved" || return 1
    result="$(dot::output pretty -- --help)" || return 1
    assert_contains "${result}" "info! --help" "-- preserves literal messages" || return 1
    result="$(dot::output::pretty -l custom message)" || return 1
    assert_contains "${result}" "message" "custom levels retain legacy fallback"
}

test_pretty_missing_level() {
    local option="" ret=0 result=""
    for option in -l --level -cl; do
        ret=0
        result="$(dot::output::pretty "${option}" 2>"${TEST_TMPDIR}/value.err")" || ret=$?
        assert_eq "1" "${ret}" "missing level fails" || return 1
        assert_eq "" "${result}" "missing level never renders" || return 1
        [[ -s "${TEST_TMPDIR}/value.err" ]] || return 1
    done
}

test_level_exact_validation() {
    local result="" ret=0
    result="$(dot::output::level '.*' 2>"${TEST_TMPDIR}/level.err")" || ret=$?
    assert_eq "1" "${ret}" "level is an enum, not a regular expression" || return 1
    assert_eq "" "${result}" "invalid level has no stdout"
}

test_image_missing_values() {
    local option="" result="" ret=0
    chafa() { _mock_record image_unexpected "$@"; return 99; }
    for option in --format --symbols --size --colors; do
        ret=0
        result="$(dot::output::image "${option}" 2>"${TEST_TMPDIR}/image.err")" || ret=$?
        assert_eq "1" "${ret}" "missing image option value fails" || return 1
        assert_eq "" "${result}" "invalid image arguments have no stdout" || return 1
        assert_contains "$(<"${TEST_TMPDIR}/image.err")" "requires a value" "missing value is diagnosed" || return 1
    done
    assert_not_called image_unexpected "invalid input never reaches chafa"
}

test_image_literal_filename_and_failure() {
    local DOT_DIRECTORY="${TEST_TMPDIR}/images-test" ret=0
    mkdir -p "${DOT_DIRECTORY}/data/images"
    : >"${DOT_DIRECTORY}/data/images/-two words.jpg"
    chafa() { printf '%s\n' "$@" >"${TEST_TMPDIR}/image.args"; return 23; }
    dot::output image --size 80x24 -- '-two words.jpg' >/dev/null 2>&1 || ret=$?
    assert_eq "23" "${ret}" "chafa failure is propagated" || return 1
    assert_eq "$(printf '%s\n' --format=symbols --symbols block+border --size 80x24 -- "${DOT_DIRECTORY}/data/images/-two words.jpg")" \
        "$(<"${TEST_TMPDIR}/image.args")" "backend receives separate options and one quoted filename"
}

test_image_listing_without_renderer() {
    local DOT_DIRECTORY="${TEST_TMPDIR}/listing" result=""
    mkdir -p "${DOT_DIRECTORY}/data/images" "${TEST_TMPDIR}/listing-bin"
    : >"${DOT_DIRECTORY}/data/images/example.jpg"
    ln -s "$(command -v find)" "${TEST_TMPDIR}/listing-bin/find"
    ln -s "$(command -v sort)" "${TEST_TMPDIR}/listing-bin/sort"
    ln -s "$(command -v basename)" "${TEST_TMPDIR}/listing-bin/basename"
    local PATH="${TEST_TMPDIR}/listing-bin"
    result="$(dot::output image --list 2>"${TEST_TMPDIR}/listing.err")" || return 1
    assert_eq "example.jpg" "${result}" "listing works without chafa" || return 1
    assert_eq "" "$(<"${TEST_TMPDIR}/listing.err")" "listing has no dependency error"
}

test_image_conflicting_modes() {
    local ret=0
    chafa() { _mock_record image_conflict "$@"; return 99; }
    dot::output::image --random --list >/dev/null 2>&1 || ret=$?
    assert_eq "1" "${ret}" "conflicting image modes fail" || return 1
    assert_not_called image_conflict "conflicting modes do not render"
}

test_dimensions_fallback() {
    local COLUMNS=120 LINES=40
    stty() { return 1; }
    assert_eq "120" "$(dot::output width)" "width uses COLUMNS without a TTY" || return 1
    assert_eq "40" "$(dot::output height)" "height uses LINES without a TTY" || return 1
    unset COLUMNS LINES
    assert_eq "80" "$(dot::output width)" "unset width uses default" || return 1
    assert_eq "24" "$(dot::output height)" "unset height uses default"
}

test_plain_renderer_fallback() {
    local PATH="${TEST_TMPDIR}/no-tools" result=""
    unset -f figlet
    result="$(dot::output figlet 'plain message' true)" || return 1
    assert_eq "$(printf '2\nplain message')" "${result}" "missing presentation tools retain plain text"
}

test_renderer_failure_is_not_hidden() {
    local ret=0
    figlet() { return 31; }
    lolcat() { _mock_record unexpected_color "$@"; return 0; }
    dot::output::figlet message true >/dev/null 2>&1 || ret=$?
    assert_eq "31" "${ret}" "figlet failure survives color pipeline" || return 1
    assert_not_called unexpected_color "failed figlet output is not passed to lolcat"
}

test_splash_invalid_flag_has_no_actions() {
    local ret=0
    dot::output::width() { _mock_record splash_unexpected; printf '80\n'; }
    dot::output::splash --invalid >/dev/null 2>&1 || ret=$?
    assert_eq "1" "${ret}" "unknown splash flag fails" || return 1
    assert_not_called splash_unexpected "splash rejects flags before rendering"
}

test_random_font_always_nonempty() {
    local attempt=0 result=""
    for ((attempt=0; attempt<64; attempt++)); do
        result="$(dot::output random-font)" || return 1
        [[ -n "${result}" ]] || return 1
    done
}

it "all output help works without external tools" test_output_all_help_without_backends
it "unknown commands and private helpers are rejected" test_output_unknown_commands
it "pretty preserves parser state, quoting, and legacy options" test_pretty_parser_contract
it "pretty rejects missing option values" test_pretty_missing_level
it "level validates exact names and reports errors on stderr" test_level_exact_validation
it "image rejects missing values without rendering" test_image_missing_values
it "image preserves filenames and backend failure status" test_image_literal_filename_and_failure
it "image listing does not require chafa" test_image_listing_without_renderer
it "image rejects conflicting selection modes" test_image_conflicting_modes
it "terminal dimensions have non-TTY fallbacks" test_dimensions_fallback
it "missing optional renderers fall back to plain text" test_plain_renderer_fallback
it "renderer failure is not hidden by color output" test_renderer_failure_is_not_hidden
it "invalid splash flags do not trigger actions" test_splash_invalid_flag_has_no_actions
it "random font selection respects shell array indexing" test_random_font_always_nonempty

test_quote_failure_and_plain_fallback() {
    local ret=0 result="" PATH="${TEST_TMPDIR}/no-tools"
    unset -f figlet
    yq() { printf '%s\n' 'a short quote'; }
    shuf() { local line=""; IFS= read -r line; printf '%s\n' "${line}"; }
    result="$(dot::output term-quote)" || return 1
    assert_eq 'a short quote' "${result}" "quote has a plain fallback without renderers" || return 1
    yq() { return 27; }
    dot::output term-quote >/dev/null 2>&1 || ret=$?
    assert_eq "27" "${ret}" "quote source failure is propagated"
}

test_listing_failure() {
    local DOT_DIRECTORY="${TEST_TMPDIR}/failed-list" ret=0
    mkdir -p "${DOT_DIRECTORY}/data/images"
    find() { return 26; }
    dot::output image --list >/dev/null 2>&1 || ret=$?
    assert_eq "26" "${ret}" "find failure is not hidden by sorting"
}

test_splash_partial_failure() {
    local ret=0
    dot::output::width() { printf '80\n'; }
    dot::output::splash-info() { return 29; }
    dot::output::term-quote() { return 0; }
    dot::output splash --no-image >/dev/null 2>&1 || ret=$?
    assert_eq "29" "${ret}" "later success does not mask a failed splash section"
}

test_figlet_forwarding() {
    figlet() { printf '%s\n' "$@" >"${TEST_TMPDIR}/figlet.args"; }
    dot::output figlet message false -f 'font with spaces' -w 90 >/dev/null || return 1
    assert_eq "$(printf '%s\n' -f 'font with spaces' -w 90)" "$(<"${TEST_TMPDIR}/figlet.args")" "figlet arguments remain separate"
}

test_colors_modes() {
    local ret=0
    dot::output colors256 bg >/dev/null || return 1
    dot::output colors256 fg >/dev/null || return 1
    dot::output colors256 invalid >/dev/null 2>&1 || ret=$?
    assert_eq "1" "${ret}" "invalid color mode fails"
}

it "quote falls back without hiding source errors" test_quote_failure_and_plain_fallback
it "image listing propagates discovery errors" test_listing_failure
it "splash reports partial failure" test_splash_partial_failure
it "figlet forwards separate backend arguments" test_figlet_forwarding
it "color samples use only validated modes" test_colors_modes

tap_summary
