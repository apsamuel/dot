#!/usr/local/bin/bash
#% author: Aaron Samuel
#% description: math utility functions (arithmetic, algebra, trig, calculus)
# shellcheck shell=bash

DOT_MATH_SCALE="${DOT_MATH_SCALE:-10}"

dot::math::help() {
    local topic="${1:-}" usage="" example="" details=""
    case "${topic}" in
        ''|help|-h|--help)
            printf '%s\n' 'Usage: dot::math <command> [args]' \
                'Evaluate expressions and perform arithmetic, algebra, trigonometry, and numerical calculus.' \
                'Commands:' \
                '  solve, pi, e, tau, sin, cos, tan, atan, atan2, deg2rad, rad2deg' \
                '  exp, ln, log10, log2, pow, sqrt, cbrt, abs, factorial, gcd, lcm' \
                '  quadratic, derivative, integral, min, max, clamp, round, ceil, floor, sum, mean' \
                'Use dot::math help <command> for arguments and prerequisites.'
            return 0 ;;
        solve) usage='solve EXPRESSION [--scale N]'; example='solve "2 + 3" --scale 4'; details="--scale N: nonnegative decimal precision (default: ${DOT_MATH_SCALE})." ;;
        pi|e|tau) usage="${topic}"; example="${topic}" ;;
        sin|cos|tan) usage="${topic} RADIANS"; example="${topic} -1" ;;
        atan|exp|ln|log10|log2|sqrt|cbrt|abs|ceil|floor) usage="${topic} VALUE"; example="${topic} 2" ;;
        atan2) usage='atan2 Y X'; example='atan2 1 -1' ;;
        deg2rad) usage='deg2rad DEGREES'; example='deg2rad 90' ;;
        rad2deg) usage='rad2deg RADIANS'; example='rad2deg 1' ;;
        pow) usage='pow BASE EXPONENT'; example='pow 2 3' ;;
        factorial) usage='factorial INTEGER'; example='factorial 5'; details='Requires a nonnegative integer. Uses shell arithmetic; results are limited by its integer range.' ;;
        gcd|lcm) usage="${topic} INTEGER INTEGER"; example="${topic} 12 18"; details='Uses shell integer arithmetic.' ;;
        quadratic) usage='quadratic A B C'; example='quadratic 1 -3 2' ;;
        derivative) usage='derivative EXPRESSION AT_X [--h STEP]'; example='derivative "x*x" 2'; details='Use x in the expression; --h is a positive step (default: 0.0000001).' ;;
        integral) usage='integral EXPRESSION FROM TO [--n INTERVALS]'; example='integral "x*x" 0 1'; details='Use x in the expression; --n is positive (default: 1000); odd intervals round up to even.' ;;
        min|max) usage="${topic} VALUE VALUE"; example="${topic} -2 3" ;;
        clamp) usage='clamp VALUE MIN MAX'; example='clamp 5 0 3' ;;
        round) usage='round VALUE [PLACES]'; example='round 1.234 2'; details='PLACES is nonnegative (default: 0).' ;;
        sum|mean) usage="${topic} VALUE [VALUE...]"; example="${topic} -1 2 3" ;;
        *) printf 'dot::math help: unknown command: %s\n' "${topic}" >&2; return 1 ;;
    esac
    printf 'Usage: dot::math %s\n       dot::math::%s\n\n' "${usage}" "${usage}"
    [[ -z "${details}" ]] || printf '%s\n' "${details}"
    case "${topic}" in
        factorial|gcd|lcm) ;;
        *) printf 'Requires bc. Precision defaults to DOT_MATH_SCALE=%s.\n' "${DOT_MATH_SCALE}" ;;
    esac
    printf 'Example: dot::math %s\nHelp: -h, --help before operands. Returns 0 on success, nonzero on failure. No persistent changes.\n' "${example}"
}

dot::math() {
    local action="${1:-help}"
    [[ $# -gt 0 ]] && shift
    case "${action}" in
        help|-h|--help) dot::math::help "$@" ;;
        solve) dot::math::solve "$@" ;;
        pi) dot::math::pi "$@" ;;
        e) dot::math::e "$@" ;;
        tau) dot::math::tau "$@" ;;
        sin) dot::math::sin "$@" ;;
        cos) dot::math::cos "$@" ;;
        tan) dot::math::tan "$@" ;;
        atan) dot::math::atan "$@" ;;
        atan2) dot::math::atan2 "$@" ;;
        deg2rad) dot::math::deg2rad "$@" ;;
        rad2deg) dot::math::rad2deg "$@" ;;
        exp) dot::math::exp "$@" ;;
        ln) dot::math::ln "$@" ;;
        log10) dot::math::log10 "$@" ;;
        log2) dot::math::log2 "$@" ;;
        pow) dot::math::pow "$@" ;;
        sqrt) dot::math::sqrt "$@" ;;
        cbrt) dot::math::cbrt "$@" ;;
        abs) dot::math::abs "$@" ;;
        factorial) dot::math::factorial "$@" ;;
        gcd) dot::math::gcd "$@" ;;
        lcm) dot::math::lcm "$@" ;;
        quadratic) dot::math::quadratic "$@" ;;
        derivative) dot::math::derivative "$@" ;;
        integral) dot::math::integral "$@" ;;
        min) dot::math::min "$@" ;;
        max) dot::math::max "$@" ;;
        clamp) dot::math::clamp "$@" ;;
        round) dot::math::round "$@" ;;
        ceil) dot::math::ceil "$@" ;;
        floor) dot::math::floor "$@" ;;
        sum) dot::math::sum "$@" ;;
        mean) dot::math::mean "$@" ;;
        *) printf 'dot::math: unknown command: %s (use dot::math help)\n' "${action}" >&2; return 1 ;;
    esac
}

# --- Core ---

dot::math::_evaluate() {
    case "${DOT_MATH_SCALE}" in ''|*[!0-9]*) printf '%s\n' 'dot::math: DOT_MATH_SCALE must be a nonnegative integer' >&2; return 1 ;; esac
    command -v bc >/dev/null 2>&1 || { printf '%s\n' 'dot::math: bc is required' >&2; return 1; }
    local program="$1"
    shift
    printf '%s\n' "${program}" | bc "$@"
}

dot::math::solve() {
    # Evaluate an arbitrary math expression via bc
    # Usage: dot::math::solve <expression> [--scale N]
    local scale="${DOT_MATH_SCALE}"
    local expression=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --scale)
                [[ $# -ge 2 && -n "${2:-}" ]] || { printf '%s\n' 'dot::math::solve: --scale requires a value' >&2; return 1; }
                scale="$2"; shift 2 ;;
            --scale=*) scale="${1#*=}"; shift ;;
            --help|-h)
                dot::math::help solve; return ;;
            --)
                shift
                [[ $# -eq 1 && -z "${expression}" ]] || { printf '%s\n' 'dot::math::solve: expected one expression' >&2; return 1; }
                expression="$1"; break ;;
            --*) printf 'dot::math::solve: unknown option: %s\n' "$1" >&2; return 1 ;;
            *)
                [[ -z "${expression}" ]] || { printf '%s\n' 'dot::math::solve: expected one expression' >&2; return 1; }
                expression="$1"; shift ;;
        esac
    done

    if [[ -z "${expression}" ]]; then
        echo "Usage: dot::math::solve <expression> [--scale N]" >&2
        return 1
    fi

    case "${scale}" in ''|*[!0-9]*) printf '%s\n' 'dot::math::solve: scale must be a nonnegative integer' >&2; return 1 ;; esac
    dot::math::_evaluate "scale=${scale}; ${expression}" -l
}

# --- Constants ---

dot::math::pi() {
    case "${1:-}" in -h|--help) dot::math::help pi; return ;; esac
    dot::math::_evaluate "scale=${DOT_MATH_SCALE}; 4*a(1)" -l
}
dot::math::e() {
    case "${1:-}" in -h|--help) dot::math::help e; return ;; esac
    dot::math::_evaluate "scale=${DOT_MATH_SCALE}; e(1)" -l
}
dot::math::tau() {
    case "${1:-}" in -h|--help) dot::math::help tau; return ;; esac
    dot::math::_evaluate "scale=${DOT_MATH_SCALE}; 8*a(1)" -l
}

# --- Trigonometry (input in radians) ---

dot::math::sin() {
    case "${1:-}" in -h|--help) dot::math::help sin; return ;; --) shift ;; esac
    [[ $# -eq 1 && -n "${1:-}" ]] || { dot::math::help sin >&2; return 1; }
    local x="$1"
    dot::math::_evaluate "scale=${DOT_MATH_SCALE}; s(${x})" -l
}

dot::math::cos() {
    case "${1:-}" in -h|--help) dot::math::help cos; return ;; --) shift ;; esac
    [[ $# -eq 1 && -n "${1:-}" ]] || { dot::math::help cos >&2; return 1; }
    local x="$1"
    dot::math::_evaluate "scale=${DOT_MATH_SCALE}; c(${x})" -l
}

dot::math::tan() {
    case "${1:-}" in -h|--help) dot::math::help tan; return ;; --) shift ;; esac
    [[ $# -eq 1 && -n "${1:-}" ]] || { dot::math::help tan >&2; return 1; }
    local x="$1"
    dot::math::_evaluate "scale=${DOT_MATH_SCALE}; s(${x})/c(${x})" -l
}

dot::math::atan() {
    case "${1:-}" in -h|--help) dot::math::help atan; return ;; --) shift ;; esac
    [[ $# -eq 1 && -n "${1:-}" ]] || { dot::math::help atan >&2; return 1; }
    local x="$1"
    dot::math::_evaluate "scale=${DOT_MATH_SCALE}; a(${x})" -l
}

dot::math::atan2() {
    case "${1:-}" in -h|--help) dot::math::help atan2; return ;; --) shift ;; esac
    [[ $# -eq 2 && -n "${1:-}" && -n "${2:-}" ]] || { dot::math::help atan2 >&2; return 1; }
    local y="$1" x="$2"
    # atan2(y,x) via bc: handle quadrants
    dot::math::_evaluate "scale=${DOT_MATH_SCALE}; if(${x}>0) a(${y}/${x}) else if(${x}<0 && ${y}>=0) a(${y}/${x})+4*a(1) else if(${x}<0 && ${y}<0) a(${y}/${x})-4*a(1) else if(${x}==0 && ${y}>0) 2*a(1) else if(${x}==0 && ${y}<0) -2*a(1) else 0" -l
}

dot::math::deg2rad() {
    case "${1:-}" in -h|--help) dot::math::help deg2rad; return ;; --) shift ;; esac
    [[ $# -eq 1 && -n "${1:-}" ]] || { dot::math::help deg2rad >&2; return 1; }
    local deg="$1"
    dot::math::_evaluate "scale=${DOT_MATH_SCALE}; ${deg}*4*a(1)/180" -l
}

dot::math::rad2deg() {
    case "${1:-}" in -h|--help) dot::math::help rad2deg; return ;; --) shift ;; esac
    [[ $# -eq 1 && -n "${1:-}" ]] || { dot::math::help rad2deg >&2; return 1; }
    local rad="$1"
    dot::math::_evaluate "scale=${DOT_MATH_SCALE}; ${rad}*180/(4*a(1))" -l
}

# --- Exponentials & Logarithms ---

dot::math::exp() {
    case "${1:-}" in -h|--help) dot::math::help exp; return ;; --) shift ;; esac
    [[ $# -eq 1 && -n "${1:-}" ]] || { dot::math::help exp >&2; return 1; }
    local x="$1"
    dot::math::_evaluate "scale=${DOT_MATH_SCALE}; e(${x})" -l
}

dot::math::ln() {
    case "${1:-}" in -h|--help) dot::math::help ln; return ;; --) shift ;; esac
    [[ $# -eq 1 && -n "${1:-}" ]] || { dot::math::help ln >&2; return 1; }
    local x="$1"
    dot::math::_evaluate "scale=${DOT_MATH_SCALE}; l(${x})" -l
}

dot::math::log10() {
    case "${1:-}" in -h|--help) dot::math::help log10; return ;; --) shift ;; esac
    [[ $# -eq 1 && -n "${1:-}" ]] || { dot::math::help log10 >&2; return 1; }
    local x="$1"
    dot::math::_evaluate "scale=${DOT_MATH_SCALE}; l(${x})/l(10)" -l
}

dot::math::log2() {
    case "${1:-}" in -h|--help) dot::math::help log2; return ;; --) shift ;; esac
    [[ $# -eq 1 && -n "${1:-}" ]] || { dot::math::help log2 >&2; return 1; }
    local x="$1"
    dot::math::_evaluate "scale=${DOT_MATH_SCALE}; l(${x})/l(2)" -l
}

dot::math::pow() {
    case "${1:-}" in -h|--help) dot::math::help pow; return ;; --) shift ;; esac
    [[ $# -eq 2 && -n "${1:-}" && -n "${2:-}" ]] || { dot::math::help pow >&2; return 1; }
    local base="$1" exp="$2"
    dot::math::_evaluate "scale=${DOT_MATH_SCALE}; e(${exp}*l(${base}))" -l
}

dot::math::sqrt() {
    case "${1:-}" in -h|--help) dot::math::help sqrt; return ;; --) shift ;; esac
    [[ $# -eq 1 && -n "${1:-}" ]] || { dot::math::help sqrt >&2; return 1; }
    local x="$1"
    dot::math::_evaluate "scale=${DOT_MATH_SCALE}; sqrt(${x})" -l
}

dot::math::cbrt() {
    case "${1:-}" in -h|--help) dot::math::help cbrt; return ;; --) shift ;; esac
    [[ $# -eq 1 && -n "${1:-}" ]] || { dot::math::help cbrt >&2; return 1; }
    local x="$1"
    dot::math::_evaluate "scale=${DOT_MATH_SCALE}; e(l(${x})/3)" -l
}

# --- Algebra ---

dot::math::abs() {
    case "${1:-}" in -h|--help) dot::math::help abs; return ;; --) shift ;; esac
    [[ $# -eq 1 && -n "${1:-}" ]] || { dot::math::help abs >&2; return 1; }
    local x="$1"
    dot::math::_evaluate "scale=${DOT_MATH_SCALE}; if(${x}<0) -(${x}) else ${x}" -l
}

dot::math::_integer() {
    local value="${1:-}" digits="${1#[-+]}"
    case "${digits}" in ''|*[!0-9]*) printf '%s\n' 'dot::math: expected a decimal integer' >&2; return 1 ;; esac
    while [[ "${digits}" == 0* && "${digits}" != 0 ]]; do digits="${digits#0}"; done
    [[ "${value}" != -* || "${digits}" == 0 ]] || digits="-${digits}"
    printf '%s\n' "${digits}"
}

dot::math::factorial() {
    case "${1:-}" in -h|--help) dot::math::help factorial; return ;; --) shift ;; esac
    [[ $# -eq 1 && -n "${1:-}" ]] || { dot::math::help factorial >&2; return 1; }
    local n=""
    n="$(dot::math::_integer "$1")" || return $?
    if [[ "${n}" -lt 0 ]]; then
        echo "error: factorial undefined for negative integers" >&2
        return 1
    fi
    local result=1
    local i
    for ((i=2; i<=n; i++)); do
        result=$((result * i))
    done
    echo "${result}"
}

dot::math::gcd() {
    case "${1:-}" in -h|--help) dot::math::help gcd; return ;; --) shift ;; esac
    [[ $# -eq 2 && -n "${1:-}" && -n "${2:-}" ]] || { dot::math::help gcd >&2; return 1; }
    local a="" b=""
    a="$(dot::math::_integer "$1")" || return $?
    b="$(dot::math::_integer "$2")" || return $?
    # Euclidean algorithm
    while [[ "${b}" -ne 0 ]]; do
        local temp="${b}"
        b=$((a % b))
        a="${temp}"
    done
    echo "${a#-}"
}

dot::math::lcm() {
    case "${1:-}" in -h|--help) dot::math::help lcm; return ;; --) shift ;; esac
    [[ $# -eq 2 && -n "${1:-}" && -n "${2:-}" ]] || { dot::math::help lcm >&2; return 1; }
    local a="" b="" g=""
    a="$(dot::math::_integer "$1")" || return $?
    b="$(dot::math::_integer "$2")" || return $?
    g=$(dot::math::gcd "${a}" "${b}") || return $?
    [[ "${g}" != 0 ]] || { printf '%s\n' 0; return 0; }
    echo $(( (a * b) / g ))
}

dot::math::quadratic() {
    # Solve ax^2 + bx + c = 0, print real roots
    case "${1:-}" in -h|--help) dot::math::help quadratic; return ;; --) shift ;; esac
    [[ $# -eq 3 && -n "${1:-}" && -n "${2:-}" && -n "${3:-}" ]] || { dot::math::help quadratic >&2; return 1; }
    local a="$1" b="$2" c="$3" discriminant="" sign=""
    sign=$(dot::math::_evaluate "(${a}) == 0" -l) || return $?
    [[ "${sign}" != 1 ]] || { printf '%s\n' 'dot::math::quadratic: A must be nonzero' >&2; return 1; }
    discriminant=$(dot::math::_evaluate "scale=${DOT_MATH_SCALE}; ${b}^2 - 4*${a}*${c}" -l) || return $?

    sign=$(dot::math::_evaluate "${discriminant} < 0" -l) || return $?
    if [[ "${sign}" -eq 1 ]]; then
        echo "no real roots (discriminant = ${discriminant})" >&2
        return 1
    fi

    local sqrt_d="" x1="" x2=""
    sqrt_d=$(dot::math::_evaluate "scale=${DOT_MATH_SCALE}; sqrt(${discriminant})" -l) || return $?
    x1=$(dot::math::_evaluate "scale=${DOT_MATH_SCALE}; (-(${b}) + ${sqrt_d}) / (2*${a})" -l) || return $?
    x2=$(dot::math::_evaluate "scale=${DOT_MATH_SCALE}; (-(${b}) - ${sqrt_d}) / (2*${a})" -l) || return $?
    echo "x1=${x1}"
    echo "x2=${x2}"
}

# --- Calculus (numerical) ---

dot::math::derivative() {
    # Numerical derivative of an expression at a point
    # Usage: dot::math::derivative <expr_with_x> <at_x> [--h step]
    local expr="" at="" h="0.0000001" parse_options=1

    while [[ $# -gt 0 ]]; do
        if [[ "${parse_options}" -eq 1 ]]; then
            case "$1" in
                --h)
                    [[ $# -ge 2 && -n "${2:-}" ]] || { printf '%s\n' 'dot::math::derivative: --h requires a value' >&2; return 1; }
                    h="$2"; shift 2; continue ;;
                --h=*) h="${1#*=}"; shift; continue ;;
                --help|-h) dot::math::help derivative; return ;;
                --) parse_options=0; shift; continue ;;
                --*) printf 'dot::math::derivative: unknown option: %s\n' "$1" >&2; return 1 ;;
            esac
        fi
        if [[ -z "${expr}" ]]; then expr="$1"
        elif [[ -z "${at}" ]]; then at="$1"
        else dot::math::help derivative >&2; return 1
        fi
        shift
    done

    if [[ -z "${expr}" || -z "${at}" ]]; then
        echo "Usage: dot::math::derivative <expr> <at_x> [--h step]" >&2
        return 1
    fi

    [[ -n "${h}" ]] || { printf '%s\n' 'dot::math::derivative: step must be positive' >&2; return 1; }
    local f_plus="" f_minus="" positive=""
    positive=$(dot::math::_evaluate "(${h}) > 0" -l) || return $?
    [[ "${positive}" == 1 ]] || { printf '%s\n' 'dot::math::derivative: step must be positive' >&2; return 1; }
    local expr_plus="${expr//x/(${at}+${h})}"
    local expr_minus="${expr//x/(${at}-${h})}"

    f_plus=$(dot::math::_evaluate "scale=${DOT_MATH_SCALE}; ${expr_plus}" -l) || return $?
    f_minus=$(dot::math::_evaluate "scale=${DOT_MATH_SCALE}; ${expr_minus}" -l) || return $?

    dot::math::_evaluate "scale=${DOT_MATH_SCALE}; (${f_plus} - ${f_minus}) / (2*${h})" -l
}

dot::math::integral() {
    # Numerical integration (Simpson's rule)
    # Usage: dot::math::integral <expr_with_x> <from> <to> [--n intervals]
    local expr="" from="" to="" n=1000 parse_options=1

    while [[ $# -gt 0 ]]; do
        if [[ "${parse_options}" -eq 1 ]]; then
            case "$1" in
                --n)
                    [[ $# -ge 2 && -n "${2:-}" ]] || { printf '%s\n' 'dot::math::integral: --n requires a value' >&2; return 1; }
                    n="$2"; shift 2; continue ;;
                --n=*) n="${1#*=}"; shift; continue ;;
                --help|-h) dot::math::help integral; return ;;
                --) parse_options=0; shift; continue ;;
                --*) printf 'dot::math::integral: unknown option: %s\n' "$1" >&2; return 1 ;;
            esac
        fi
        if [[ -z "${expr}" ]]; then expr="$1"
        elif [[ -z "${from}" ]]; then from="$1"
        elif [[ -z "${to}" ]]; then to="$1"
        else dot::math::help integral >&2; return 1
        fi
        shift
    done

    if [[ -z "${expr}" || -z "${from}" || -z "${to}" ]]; then
        echo "Usage: dot::math::integral <expr> <from> <to> [--n intervals]" >&2
        return 1
    fi

    n="$(dot::math::_integer "${n}")" || return $?
    [[ "${n}" -gt 0 ]] || { printf '%s\n' 'dot::math::integral: intervals must be positive' >&2; return 1; }
    # Ensure n is even
    if (( n % 2 != 0 )); then
        n=$((n + 1))
    fi

    # Build bc program for Simpson's rule
    local bc_prog=""
    bc_prog="scale=${DOT_MATH_SCALE}
a = ${from}
b = ${to}
n = ${n}
h = (b - a) / n
sum = 0
/* endpoints */
x = a; sum = sum + (${expr})
x = b; sum = sum + (${expr})
/* odd indices: coefficient 4 */
for (i = 1; i <= n-1; i += 2) {
    x = a + i * h
    sum = sum + 4 * (${expr})
}
/* even indices: coefficient 2 */
for (i = 2; i <= n-2; i += 2) {
    x = a + i * h
    sum = sum + 2 * (${expr})
}
sum * h / 3
"
    dot::math::_evaluate "${bc_prog}" -l
}

# --- Utility ---

dot::math::min() {
    case "${1:-}" in -h|--help) dot::math::help min; return ;; --) shift ;; esac
    [[ $# -eq 2 && -n "${1:-}" && -n "${2:-}" ]] || { dot::math::help min >&2; return 1; }
    local a="$1" b="$2"
    dot::math::_evaluate "scale=${DOT_MATH_SCALE}; if(${a}<${b}) ${a} else ${b}" -l
}

dot::math::max() {
    case "${1:-}" in -h|--help) dot::math::help max; return ;; --) shift ;; esac
    [[ $# -eq 2 && -n "${1:-}" && -n "${2:-}" ]] || { dot::math::help max >&2; return 1; }
    local a="$1" b="$2"
    dot::math::_evaluate "scale=${DOT_MATH_SCALE}; if(${a}>${b}) ${a} else ${b}" -l
}

dot::math::clamp() {
    case "${1:-}" in -h|--help) dot::math::help clamp; return ;; --) shift ;; esac
    [[ $# -eq 3 && -n "${1:-}" && -n "${2:-}" && -n "${3:-}" ]] || { dot::math::help clamp >&2; return 1; }
    local val="$1" lo="$2" hi="$3" r=""
    r=$(dot::math::max "${val}" "${lo}") || return $?
    dot::math::min "${r}" "${hi}"
}

dot::math::round() {
    case "${1:-}" in -h|--help) dot::math::help round; return ;; --) shift ;; esac
    [[ $# -ge 1 && $# -le 2 && -n "${1:-}" ]] || { dot::math::help round >&2; return 1; }
    local x="$1" result=""
    local places="${2:-0}"
    case "${places}" in *[!0-9]*) printf '%s\n' 'dot::math::round: places must be a nonnegative integer' >&2; return 1 ;; esac
    result=$(dot::math::_evaluate "scale=${DOT_MATH_SCALE}; ${x}" -l) || return $?
    printf "%.${places}f\n" "${result}"
}

dot::math::ceil() {
    case "${1:-}" in -h|--help) dot::math::help ceil; return ;; --) shift ;; esac
    [[ $# -eq 1 && -n "${1:-}" ]] || { dot::math::help ceil >&2; return 1; }
    local x="$1" int_part="" diff="" positive=""
    int_part=$(dot::math::_evaluate "scale=0; ${x}/1") || return $?
    diff=$(dot::math::_evaluate "scale=${DOT_MATH_SCALE}; ${x} - ${int_part}" -l) || return $?
    positive=$(dot::math::_evaluate "${diff} > 0" -l) || return $?
    if [[ "${positive}" -eq 1 ]]; then
        echo $((int_part + 1))
    else
        echo "${int_part}"
    fi
}

dot::math::floor() {
    case "${1:-}" in -h|--help) dot::math::help floor; return ;; --) shift ;; esac
    [[ $# -eq 1 && -n "${1:-}" ]] || { dot::math::help floor >&2; return 1; }
    local x="$1"
    dot::math::_evaluate "scale=0; ${x}/1"
}

dot::math::sum() {
    case "${1:-}" in -h|--help) dot::math::help sum; return ;; --) shift ;; esac
    # Sum all arguments
    if [[ $# -eq 0 ]]; then
        echo "Usage: dot::math::sum <n1> <n2> [n3...]" >&2
        return 1
    fi
    local expr="0"
    local arg=""
    for arg in "$@"; do
        [[ -n "${arg}" ]] || { dot::math::help sum >&2; return 1; }
        expr="${expr}+${arg}"
    done
    dot::math::_evaluate "scale=${DOT_MATH_SCALE}; ${expr}" -l
}

dot::math::mean() {
    case "${1:-}" in -h|--help) dot::math::help mean; return ;; --) shift ;; esac
    # Arithmetic mean of all arguments
    if [[ $# -eq 0 ]]; then
        echo "Usage: dot::math::mean <n1> <n2> [n3...]" >&2
        return 1
    fi
    local s=""
    s=$(dot::math::sum "$@") || return $?
    dot::math::_evaluate "scale=${DOT_MATH_SCALE}; ${s}/${#}" -l
}
