#% author: Aaron Samuel
#% description: shell output functions
# shellcheck shell=bash

#** disable relevant shellcheck warnings **#
# shellcheck source=/dev/null
# shellcheck disable=SC2207

DOT_DEBUG="${DOT_DEBUG:-0}"
directory=$(dirname "$0")
library=$(basename "$0")


if [[ "${DOT_DEBUG}" -eq 1 ]]; then
    echo "loading: ${library} (${directory})"
fi


if [[ "${DOT_DISABLE_OUTPUTS}" -eq 1 ]]; then
    return
fi


# --- dot:: logging helpers are defined in static/logging.sh ---
# (loaded before dynamic modules by zshrc)


# default colors for output
info_color="$(tput setab 238)$(tput setaf 250)"
error_color="$(tput setab 232)$(tput setaf 160)"
debug_color="$(tput setab 238)$(tput setaf 250)"
reset_color="$(tput sgr0)"


# default emojis for output (legacy — kept for dot::output::pretty compatibility)
emoji_info=" ℹ️ "
emoji_error=" 💣 "
emoji_debug=" 🛠️ "
emoji_unknown=" ❓ "


levels=(
    "info"
    "error"
    "debug"
)

function dot::output::color-tab() {
	for ((i=0; i<256; i++)) ;do
		echo -n '  '
		tput setab "$i"
		tput setaf $(( ( (i>231&&i<244 ) || ( (i<17)&& (i%8<2)) ||
			(i>16&&i<232)&& ((i-16)%6 <(i<100?3:2) ) && ((i-16)%36<15) )?7:16))
		printf " C %03d " "$i"
		tput op
		(( ((i<16||i>231) && ((i+1)%8==0)) || ((i>16&&i<232)&& ((i-15)%6==0)) )) &&
			echo ""
	done
}

function dot::output::levels() {
    local output=""
    for level in "${levels[@]}"; do
        output+="${level} "
    done
    echo "${output}"
}

function dot::output::level() {
    local level="${1}"
    if [[ -z "${level}" ]]; then
        echo "Usage: dot::output::level <level>"
        return 1
    fi

    if [[ ! " ${levels[*]} " =~  ${level}  ]]; then
        echo "Invalid level: ${level}. Available levels: $(dot::output::levels)"
        return 1
    fi

    case "${level}" in
        info) echo "${info_color}info${reset_color}" ;;
        error) echo "${error_color}error${reset_color}" ;;
        debug) echo "${debug_color}debug${reset_color}" ;;
        *) echo "${reset_color}unknown${reset_color}" ;;
    esac
}


function dot::output::pretty() {
    local message
    local level
    local color
    local emoji
    local timestamp
    local output

    output=""

    # t="$(date +%Y-%d-%m.%H.%M.%S)"

    level="info"  # default level
    color=0
    emoji=0
    timestamp=0

    while getopts ":ectl:" opt; do
        case ${opt} in
            e) emoji=1 ;;
            c) color=1 ;;
            t) timestamp=1;;
            l) level="${OPTARG}" ;;
            \?) echo "Invalid option: -$OPTARG" >&2 ;;
            :) echo "Option -$OPTARG requires an argument." >&2 ;;
        esac
    done

    local message="${*:$OPTIND:1}"
    if [[ -z "${message}" ]]; then
        echo "Usage: dot::output::pretty [-c] [-e] -l <level> <message>"
        return 1
    fi


    # if color is enabled
    if [[ "${color}" -eq 1 ]]; then
        case "${level}" in

            info)
                # use timestamp instead of level
                if [[ "${timestamp}" -eq 1 ]]; then
                    output+="${info_color}$(date +%Y-%d-%m.%H.%M.%S) "
                else
                    output+="${info_color}"
                fi
                #output+="${info_color}(info) "
                ;;
            error)
                if [[ "${timestamp}" -eq 1 ]]; then
                    output+="${error_color}$(date +%Y-%d-%m.%H.%M.%S) "
                else
                    output+="${error_color}"
                fi

                ;;
            debug)
                if [[ "${timestamp}" -eq 1 ]]; then
                    output+="${debug_color}$(date +%Y-%d-%m.%H.%M.%S) "
                else
                    output+="${debug_color}"
                fi
                #output+="${debug_color}(debug) "
                ;;
            *)
                if [[ "${timestamp}" -eq 1 ]]; then
                    output+="${reset_color}$(date +%Y-%d-%m.%H.%M.%S) "
                else
                    output+="${reset_color}"
                fi
                #output+="${reset_color}(unknown) "
                ;;
        esac
    else
        # we are using timestamps here

        output+="info! "
    fi

    # if emoji is enabled, we will add it after the timestamp

    if [[ "${emoji}" -eq 1 ]]; then
        case "${level}" in
            info) output+=" ${emoji_info} " ;;
            error) output+=" ${emoji_error} " ;;
            debug) output+=" ${emoji_debug} " ;;
            *) output+="❓ " ;;  # default emoji for unknown level
        esac
    fi

    # set timestamp
    if [[ "${timestamp}" -eq 1 ]]; then
        output+="[$(date +%Y-%d-%m.%H.%M.%S)] "
    fi

    # set emoji
    if [[ "${emoji}" -eq 1 ]]; then
        case "${level}" in
            info) output+=" ${emoji_info} " ;;
            error) output+=" ${emoji_error} " ;;
            debug) output+=" ${emoji_debug} " ;;
            *) output+="❓ " ;;  # default emoji for unknown level
        esac
    fi


    # set message
    output+="${message} "


    # reset color
    if [[ "${color}" -eq 1 ]]; then
        output+="${reset_color}"
    fi

    # adds a new line
    output+="\n"

    # print the output
    echo -n "${output}"
}

function dot::output::logo() {
    find "${ICLOUD}/dot/shell/images" -type f -name "*.jpg" | shuf -n 1 | xargs -I {} jp2a --colors --width="$(( $(dot::output::width) / 3 ))" --border --color-depth=24 --background=dark {}
}

function dot::output::image () {
    local image="${1}"

    if ! command -v kitty &> /dev/null; then
        echo "kitty is not available, please install it to use this function."
        return 1
    fi

    if [[ -z "${image}" ]]; then
        echo "Usage: dot::output::image <image_path>"
        return 1
    fi

    local window_size
    window_size="$(kitty +kitten icat --print-window-size)"
    local px_width="${window_size%%x*}"
    local px_height="${window_size##*x}"
    kitty +kitten icat --transfer-mode=stream "${image}"
    return 0


    # TERM=screen-256color "$HOME"/.iterm2/imgcat "${image}"
    # sleep 5
    # export TERM=xterm-256color
    # return 0
}


function dot::output::random-font() {
	fonts=(
		"cyberlarge"
		"elite"
		"bloody"
		"roman"
		"jacky"
		"rusto"
		"ascii12"
		"binary"
	)
	echo "${fonts[$((RANDOM % $#fonts+1 ))]}"
}

function dot::output::quote() {
	dot::output::quote="$(
		yq '.[] | .text + " -- " + .author | select(length < 45)' "${DOT_DIRECTORY}/data/quotes.yaml" | shuf -n1
	)"
	echo "${dot::output::quote}"
}

function dot::output::term-quote() {
    command -v figlet &>/dev/null || { dot::output::quote | lolcat; return 0; }

    local term_width
    term_width="$(dot::output::width)"

    # Resolve vendored font directory
    local figlet_font_dir="${DOT_DIRECTORY}/vendor/figlet-fonts"
    local use_vendor_fonts=0
    if [[ -d "${figlet_font_dir}" ]]; then
        use_vendor_fonts=1
    else
        echo "dot: vendored figlet-fonts not found at ${figlet_font_dir}" >&2
        echo "dot: run 'git submodule update --init vendor/figlet-fonts' to check it out" >&2
    fi

    # Scale max raw quote length to terminal width: wider terminal → longer quotes
    local max_len=$(( term_width / 2 ))
    (( max_len < 30 )) && max_len=30
    (( max_len > 80 )) && max_len=80

    local quote
    quote="$(
        yq ".[] | .text + \" -- \" + .author | select(length < ${max_len})" \
            "${DOT_DIRECTORY}/data/quotes.yaml" | shuf -n1
    )"

    [[ -z "${quote}" ]] && return 0

    # Try fonts from decorative → minimal until one fits within the terminal width
    local preferred_font
    preferred_font="$(dot::output::random-font)"
    local fonts=("${preferred_font}" "small" "mini" "term" "banner" "standard")

    local font rendered max_line_len
    for font in "${fonts[@]}"; do
        rendered=""
        # Prefer vendored font dir; fall back to system fonts
        if (( use_vendor_fonts )); then
            rendered="$(echo "${quote}" | figlet -p -w "${term_width}" -d "${figlet_font_dir}" -f "${font}" -k 2>/dev/null)"
        fi
        if [[ -z "${rendered}" ]]; then
            rendered="$(echo "${quote}" | figlet -p -w "${term_width}" -f "${font}" -k 2>/dev/null)"
        fi
        [[ -z "${rendered}" ]] && continue

        max_line_len=$(echo "${rendered}" | awk '{ if (length > max) max = length } END { print max+0 }')
        if (( max_line_len <= term_width )); then
            echo "${rendered}" | lolcat
            return 0
        fi
    done

    # Absolute fallback: plain lolcat output
    echo "${quote}" | lolcat
}

function dot::output::figlet() {
	message="${1}"
	color="${2:-false}"
    echo "$#"
    #	shift 2
    #	args="${*}"


    if [ $# -eq 1 ]; then
        # shift 1
        message="${*}"
        figlet "$message"
    fi

    if [ $# -eq 2 ]; then
        # shift 2
        message="${1}"
        color="${2}"
        if [[ "${color}" == "true" ]]; then
            figlet "$message" | lolcat
        else
            figlet "$message"
        fi
    fi

    if [ $# -ge 3 ]; then
        message="${1}"
        color="${2}"
        shift 2
        args="${*}"
        if [[ "${color}" == "true" ]]; then
            echo "$message" | figlet "$args"| lolcat
        fi
        if [[ ! "${color}" == "true" ]]; then
            echo "$message" | figlet "$args"
        fi
    fi
}

function dot::output::height () {
	stty size | cut -d' ' -f1
}

function dot::output::width () {
	stty size | cut -d' ' -f2
}

function dot::output::colors256() {
    local row col blockrow blockcol red green blue
    local showcolor=_showcolor256_${1:-bg}
    local white="\033[1;37m"
    local reset="\033[0m"

    echo -e "set foreground: \\\\033[38;5;${white}NNN${reset}m"
    echo -e "set background: \\\\033[48;5;${white}NNN${reset}m"
    echo -e "reset color & style:  \\\\033[0m"
    echo

    echo 16 standard color codes:
    for row in {0..1}; do
        for col in {0..7}; do
            $showcolor $((row * 8 + col)) "$row"
        done
        echo
    done
    echo

    echo 6·6·6 RGB color codes:
    for blockrow in {0..2}; do
        for red in {0..5}; do
            for blockcol in {0..1}; do
                green=$((blockrow * 2 + blockcol))
                for blue in {0..5}; do
                    $showcolor $((red * 36 + green * 6 + blue + 16)) $green
                done
                echo -n "  "
            done
            echo
        done
        echo
    done

    echo 24 grayscale color codes:
    for row in {0..1}; do
        for col in {0..11}; do
            $showcolor $((row * 12 + col + 232)) "$row"
        done
        echo
    done
    echo
}

function dot::output::_color256-fg() {
    local code
    code=$(printf %03d "$1")
    echo -ne "\033[38;5;${code}m"
    echo -nE " $code "
    echo -ne "\033[0m"
}

function dot::output::_color256-bg() {
    if (($2 % 2 == 0)); then
        echo -ne "\033[1;37m"
    else
        echo -ne "\033[0;30m"
    fi
    local code
    code=$(printf %03d "$1")
    echo -ne "\033[48;5;${code}m"
    echo -nE " $code "
    echo -ne "\033[0m"
}
