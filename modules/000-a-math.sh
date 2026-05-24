#!/usr/local/bin/bash
#% author: Aaron Samuel
#% description: math utility functions (arithmetic, algebra, trig, calculus)
# shellcheck shell=bash

DOT_MATH_SCALE="${DOT_MATH_SCALE:-10}"

# --- Core ---

dot::math::solve() {
    # Evaluate an arbitrary math expression via bc
    # Usage: dot::math::solve <expression> [--scale N]
    local scale="${DOT_MATH_SCALE}"
    local expression=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --scale) scale="$2"; shift 2 ;;
            --help|-h)
                echo "Usage: dot::math::solve <expression> [--scale N]"
                echo "  Evaluate a math expression using bc"
                echo "  --scale N   decimal precision (default: ${DOT_MATH_SCALE})"
                return 0 ;;
            *) expression="$1"; shift ;;
        esac
    done

    if [[ -z "${expression}" ]]; then
        echo "Usage: dot::math::solve <expression> [--scale N]" >&2
        return 1
    fi

    echo "scale=${scale}; ${expression}" | bc -l
}

# --- Constants ---

dot::math::pi() { echo "scale=${DOT_MATH_SCALE}; 4*a(1)" | bc -l; }
dot::math::e()  { echo "scale=${DOT_MATH_SCALE}; e(1)" | bc -l; }
dot::math::tau() { echo "scale=${DOT_MATH_SCALE}; 8*a(1)" | bc -l; }

# --- Trigonometry (input in radians) ---

dot::math::sin() {
    local x="${1:?Usage: dot::math::sin <radians>}"
    echo "scale=${DOT_MATH_SCALE}; s(${x})" | bc -l
}

dot::math::cos() {
    local x="${1:?Usage: dot::math::cos <radians>}"
    echo "scale=${DOT_MATH_SCALE}; c(${x})" | bc -l
}

dot::math::tan() {
    local x="${1:?Usage: dot::math::tan <radians>}"
    echo "scale=${DOT_MATH_SCALE}; s(${x})/c(${x})" | bc -l
}

dot::math::atan() {
    local x="${1:?Usage: dot::math::atan <value>}"
    echo "scale=${DOT_MATH_SCALE}; a(${x})" | bc -l
}

dot::math::atan2() {
    local y="${1:?Usage: dot::math::atan2 <y> <x>}"
    local x="${2:?Usage: dot::math::atan2 <y> <x>}"
    # atan2(y,x) via bc: handle quadrants
    echo "scale=${DOT_MATH_SCALE}; if(${x}>0) a(${y}/${x}) else if(${x}<0 && ${y}>=0) a(${y}/${x})+4*a(1) else if(${x}<0 && ${y}<0) a(${y}/${x})-4*a(1) else if(${x}==0 && ${y}>0) 2*a(1) else if(${x}==0 && ${y}<0) -2*a(1) else 0" | bc -l
}

dot::math::deg2rad() {
    local deg="${1:?Usage: dot::math::deg2rad <degrees>}"
    echo "scale=${DOT_MATH_SCALE}; ${deg}*4*a(1)/180" | bc -l
}

dot::math::rad2deg() {
    local rad="${1:?Usage: dot::math::rad2deg <radians>}"
    echo "scale=${DOT_MATH_SCALE}; ${rad}*180/(4*a(1))" | bc -l
}

# --- Exponentials & Logarithms ---

dot::math::exp() {
    local x="${1:?Usage: dot::math::exp <value>}"
    echo "scale=${DOT_MATH_SCALE}; e(${x})" | bc -l
}

dot::math::ln() {
    local x="${1:?Usage: dot::math::ln <value>}"
    echo "scale=${DOT_MATH_SCALE}; l(${x})" | bc -l
}

dot::math::log10() {
    local x="${1:?Usage: dot::math::log10 <value>}"
    echo "scale=${DOT_MATH_SCALE}; l(${x})/l(10)" | bc -l
}

dot::math::log2() {
    local x="${1:?Usage: dot::math::log2 <value>}"
    echo "scale=${DOT_MATH_SCALE}; l(${x})/l(2)" | bc -l
}

dot::math::pow() {
    local base="${1:?Usage: dot::math::pow <base> <exp>}"
    local exp="${2:?Usage: dot::math::pow <base> <exp>}"
    echo "scale=${DOT_MATH_SCALE}; e(${exp}*l(${base}))" | bc -l
}

dot::math::sqrt() {
    local x="${1:?Usage: dot::math::sqrt <value>}"
    echo "scale=${DOT_MATH_SCALE}; sqrt(${x})" | bc -l
}

dot::math::cbrt() {
    local x="${1:?Usage: dot::math::cbrt <value>}"
    echo "scale=${DOT_MATH_SCALE}; e(l(${x})/3)" | bc -l
}

# --- Algebra ---

dot::math::abs() {
    local x="${1:?Usage: dot::math::abs <value>}"
    echo "scale=${DOT_MATH_SCALE}; if(${x}<0) -(${x}) else ${x}" | bc -l
}

dot::math::factorial() {
    local n="${1:?Usage: dot::math::factorial <integer>}"
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
    local a="${1:?Usage: dot::math::gcd <a> <b>}"
    local b="${2:?Usage: dot::math::gcd <a> <b>}"
    # Euclidean algorithm
    while [[ "${b}" -ne 0 ]]; do
        local temp="${b}"
        b=$((a % b))
        a="${temp}"
    done
    echo "${a#-}"
}

dot::math::lcm() {
    local a="${1:?Usage: dot::math::lcm <a> <b>}"
    local b="${2:?Usage: dot::math::lcm <a> <b>}"
    local g
    g=$(dot::math::gcd "${a}" "${b}")
    echo $(( (a * b) / g ))
}

dot::math::quadratic() {
    # Solve ax^2 + bx + c = 0, print real roots
    local a="${1:?Usage: dot::math::quadratic <a> <b> <c>}"
    local b="${2:?Usage: dot::math::quadratic <a> <b> <c>}"
    local c="${3:?Usage: dot::math::quadratic <a> <b> <c>}"

    local discriminant
    discriminant=$(echo "scale=${DOT_MATH_SCALE}; ${b}^2 - 4*${a}*${c}" | bc -l)

    local sign
    sign=$(echo "${discriminant} < 0" | bc -l)
    if [[ "${sign}" -eq 1 ]]; then
        echo "no real roots (discriminant = ${discriminant})" >&2
        return 1
    fi

    local sqrt_d x1 x2
    sqrt_d=$(echo "scale=${DOT_MATH_SCALE}; sqrt(${discriminant})" | bc -l)
    x1=$(echo "scale=${DOT_MATH_SCALE}; (-(${b}) + ${sqrt_d}) / (2*${a})" | bc -l)
    x2=$(echo "scale=${DOT_MATH_SCALE}; (-(${b}) - ${sqrt_d}) / (2*${a})" | bc -l)
    echo "x1=${x1}"
    echo "x2=${x2}"
}

# --- Calculus (numerical) ---

dot::math::derivative() {
    # Numerical derivative of an expression at a point
    # Usage: dot::math::derivative <expr_with_x> <at_x> [--h step]
    local expr="" at="" h="0.0000001"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --h) h="$2"; shift 2 ;;
            --help|-h)
                echo "Usage: dot::math::derivative <expr> <at_x> [--h step]"
                echo "  Compute numerical derivative of expr (use 'x' as variable)"
                echo "  --h step   step size (default: 0.0000001)"
                return 0 ;;
            *)
                if [[ -z "${expr}" ]]; then expr="$1"
                elif [[ -z "${at}" ]]; then at="$1"
                fi
                shift ;;
        esac
    done

    if [[ -z "${expr}" || -z "${at}" ]]; then
        echo "Usage: dot::math::derivative <expr> <at_x> [--h step]" >&2
        return 1
    fi

    local f_plus f_minus
    local expr_plus="${expr//x/(${at}+${h})}"
    local expr_minus="${expr//x/(${at}-${h})}"

    f_plus=$(echo "scale=${DOT_MATH_SCALE}; ${expr_plus}" | bc -l)
    f_minus=$(echo "scale=${DOT_MATH_SCALE}; ${expr_minus}" | bc -l)

    echo "scale=${DOT_MATH_SCALE}; (${f_plus} - ${f_minus}) / (2*${h})" | bc -l
}

dot::math::integral() {
    # Numerical integration (Simpson's rule)
    # Usage: dot::math::integral <expr_with_x> <from> <to> [--n intervals]
    local expr="" from="" to="" n=1000

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --n) n="$2"; shift 2 ;;
            --help|-h)
                echo "Usage: dot::math::integral <expr> <from> <to> [--n intervals]"
                echo "  Numerical integration using Simpson's rule"
                echo "  --n N   number of intervals (default: 1000, must be even)"
                return 0 ;;
            *)
                if [[ -z "${expr}" ]]; then expr="$1"
                elif [[ -z "${from}" ]]; then from="$1"
                elif [[ -z "${to}" ]]; then to="$1"
                fi
                shift ;;
        esac
    done

    if [[ -z "${expr}" || -z "${from}" || -z "${to}" ]]; then
        echo "Usage: dot::math::integral <expr> <from> <to> [--n intervals]" >&2
        return 1
    fi

    # Ensure n is even
    if (( n % 2 != 0 )); then
        n=$((n + 1))
    fi

    # Build bc program for Simpson's rule
    local bc_prog
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
    echo "${bc_prog}" | bc -l
}

# --- Utility ---

dot::math::min() {
    local a="${1:?Usage: dot::math::min <a> <b>}"
    local b="${2:?Usage: dot::math::min <a> <b>}"
    echo "scale=${DOT_MATH_SCALE}; if(${a}<${b}) ${a} else ${b}" | bc -l
}

dot::math::max() {
    local a="${1:?Usage: dot::math::max <a> <b>}"
    local b="${2:?Usage: dot::math::max <a> <b>}"
    echo "scale=${DOT_MATH_SCALE}; if(${a}>${b}) ${a} else ${b}" | bc -l
}

dot::math::clamp() {
    local val="${1:?Usage: dot::math::clamp <value> <min> <max>}"
    local lo="${2:?Usage: dot::math::clamp <value> <min> <max>}"
    local hi="${3:?Usage: dot::math::clamp <value> <min> <max>}"
    local r
    r=$(dot::math::max "${val}" "${lo}")
    dot::math::min "${r}" "${hi}"
}

dot::math::round() {
    local x="${1:?Usage: dot::math::round <value> [places]}"
    local places="${2:-0}"
    printf "%.${places}f\n" "$(echo "scale=${DOT_MATH_SCALE}; ${x}" | bc -l)"
}

dot::math::ceil() {
    local x="${1:?Usage: dot::math::ceil <value>}"
    local int_part
    int_part=$(echo "scale=0; ${x}/1" | bc)
    local diff
    diff=$(echo "scale=${DOT_MATH_SCALE}; ${x} - ${int_part}" | bc -l)
    local positive
    positive=$(echo "${diff} > 0" | bc -l)
    if [[ "${positive}" -eq 1 ]]; then
        echo $((int_part + 1))
    else
        echo "${int_part}"
    fi
}

dot::math::floor() {
    local x="${1:?Usage: dot::math::floor <value>}"
    echo "scale=0; ${x}/1" | bc
}

dot::math::sum() {
    # Sum all arguments
    if [[ $# -eq 0 ]]; then
        echo "Usage: dot::math::sum <n1> <n2> [n3...]" >&2
        return 1
    fi
    local expr="0"
    local arg
    for arg in "$@"; do
        expr="${expr}+${arg}"
    done
    echo "scale=${DOT_MATH_SCALE}; ${expr}" | bc -l
}

dot::math::mean() {
    # Arithmetic mean of all arguments
    if [[ $# -eq 0 ]]; then
        echo "Usage: dot::math::mean <n1> <n2> [n3...]" >&2
        return 1
    fi
    local s
    s=$(dot::math::sum "$@")
    echo "scale=${DOT_MATH_SCALE}; ${s}/${#}" | bc -l
}
