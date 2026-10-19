# shellcheck shell=bash
if [[ -n "${ZSH_VERSION:-}" ]]; then _test_dir="${0:A:h}"
else _test_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"; fi
source "${_test_dir}/../framework.sh"
source "${_test_dir}/../mocks/env.sh"
source "${_test_dir}/../mocks/tools.sh"
source_module "000-a-math.sh"

describe "000-a-math.sh: command interface"

test_math_help() {
    local topic="" result=""
    local PATH="${TEST_TMPDIR}/no-tools"
    bc() { _mock_record math_help_backend; return 99; }
    for topic in solve pi e tau sin cos tan atan atan2 deg2rad rad2deg exp ln log10 log2 pow sqrt cbrt abs factorial gcd lcm quadratic derivative integral min max clamp round ceil floor sum mean; do
        result="$(dot::math help "${topic}" 2>"${TEST_TMPDIR}/math.err")" || return 1
        assert_contains "${result}" 'Usage:' "${topic} has contextual help" || return 1
        assert_eq '' "$(<"${TEST_TMPDIR}/math.err")" "help stderr is empty" || return 1
        assert_eq "${result}" "$(dot::math "${topic}" --help)" "dispatcher leaf help matches topic" || return 1
        assert_eq "${result}" "$("dot::math::${topic}" -h)" "direct leaf help matches topic" || return 1
    done
    assert_not_called math_help_backend "help never invokes bc"
}

test_solve_validation() {
    local ret=0
    bc() { _mock_record invalid_math; return 99; }
    dot::math solve --scale >/dev/null 2>&1 || ret=$?
    assert_eq 1 "${ret}" "missing scale fails without aborting caller" || return 1
    ret=0
    dot::math solve 1 --scale '2;quit' >/dev/null 2>&1 || ret=$?
    assert_eq 1 "${ret}" "scale cannot inject bc statements" || return 1
    ret=0
    dot::math solve --unknown >/dev/null 2>&1 || ret=$?
    assert_eq 1 "${ret}" "unknown wrapper options fail" || return 1
    assert_not_called invalid_math "invalid options never reach bc"
}

test_solve_forwarding() {
    local result=""
    bc() { local input=""; IFS= read -r input; printf '%s\n' "${input}"; }
    result="$(dot::math solve --scale=4 -- '-2 + 3')" || return 1
    assert_eq 'scale=4; -2 + 3' "${result}" "negative expression and scale are preserved"
}

test_solve_failure() {
    local ret=0
    bc() { return 17; }
    dot::math solve '2 + 3' >/dev/null 2>&1 || ret=$?
    assert_eq 17 "${ret}" "bc failure is propagated"
}

test_math_missing_operands() {
    local topic="" ret=0
    bc() { _mock_record missing_math; return 99; }
    for topic in solve sin cos tan atan atan2 deg2rad rad2deg exp ln log10 log2 pow sqrt cbrt abs factorial gcd lcm quadratic derivative integral min max clamp round ceil floor sum mean; do
        ret=0
        dot::math "${topic}" >"${TEST_TMPDIR}/math.out" 2>"${TEST_TMPDIR}/math.err" || ret=$?
        assert_eq 1 "${ret}" "${topic} returns without aborting caller" || return 1
        assert_eq '' "$(<"${TEST_TMPDIR}/math.out")" "usage errors leave stdout empty" || return 1
        [[ -s "${TEST_TMPDIR}/math.err" ]] || return 1
    done
    assert_not_called missing_math "missing operands never reach bc"
}

test_math_integer_arguments() {
    local ret=0
    assert_eq 120 "$(dot::math factorial 05)" "leading zeros are decimal" || return 1
    assert_eq 4 "$(dot::math gcd -08 +12)" "signed integers work" || return 1
    assert_eq 0 "$(dot::math lcm 0 0)" "zero operands never divide by zero" || return 1
    dot::math factorial '2+3' >/dev/null 2>&1 || ret=$?
    assert_eq 1 "${ret}" "integer arguments are not shell expressions"
}

test_math_calculus_options() {
    local ret=0
    bc() { _mock_record invalid_calculus; return 99; }
    dot::math derivative x 1 --h >/dev/null 2>&1 || ret=$?
    assert_eq 1 "${ret}" "missing derivative step returns safely" || return 1
    ret=0
    dot::math integral x 0 1 --n >/dev/null 2>&1 || ret=$?
    assert_eq 1 "${ret}" "missing interval count returns safely" || return 1
    ret=0
    dot::math integral x 0 1 --n 0 >/dev/null 2>&1 || ret=$?
    assert_eq 1 "${ret}" "zero intervals fail before calculation" || return 1
    ret=0
    dot::math derivative x 1 --typo >/dev/null 2>&1 || ret=$?
    assert_eq 1 "${ret}" "unknown calculus options fail" || return 1
    assert_not_called invalid_calculus "invalid calculus options never reach bc"
}

test_math_integral_forwarding() {
    local result=""
    bc() { local line=""; while IFS= read -r line; do printf '%s\n' "${line}"; done; }
    result="$(dot::math integral --n 3 -- 'x*x' -1 1)" || return 1
    assert_contains "${result}" 'n = 4' "odd intervals still round up" || return 1
    assert_contains "${result}" 'a = -1' "negative bounds remain intact" || return 1
    assert_contains "${result}" '(x*x)' "quoted expression remains intact"
}

test_math_multistep_failure() {
    local topic="" ret=0
    bc() { return 23; }
    for topic in quadratic clamp; do
        ret=0
        dot::math "${topic}" 1 2 3 >/dev/null 2>&1 || ret=$?
        assert_eq 23 "${ret}" "${topic} preserves backend failure" || return 1
    done
    for topic in mean ceil round; do
        ret=0
        dot::math "${topic}" 1 >/dev/null 2>&1 || ret=$?
        assert_eq 23 "${ret}" "${topic} preserves backend failure" || return 1
    done
    ret=0
    dot::math derivative x 1 >/dev/null 2>&1 || ret=$?
    assert_eq 23 "${ret}" "derivative preserves backend failure"
}

it "contextual help requires no backend" test_math_help
it "solve validates before calculation" test_solve_validation
it "solve preserves quoted negative expressions" test_solve_forwarding
it "solve preserves backend failures" test_solve_failure
it "missing operands never abort callers" test_math_missing_operands
it "integer arguments are validated" test_math_integer_arguments
it "calculus options are checked before execution" test_math_calculus_options
it "integral preserves bounds and odd interval normalization" test_math_integral_forwarding
it "multi-step calculations propagate failures" test_math_multistep_failure

tap_summary
