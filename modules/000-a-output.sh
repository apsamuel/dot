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


if [[ "${DOT_DISABLE_OUTPUTS:-0}" -eq 1 ]]; then
    return
fi


# --- dot:: logging helpers are defined in static/logging.sh ---
# (loaded before dynamic modules by zshrc)


# default colors for output
info_color=""
error_color=""
debug_color=""
reset_color=""
if command -v tput >/dev/null 2>&1 && [[ -n "${TERM:-}" && "${TERM}" != dumb ]]; then
    info_color="$(tput setab 238 2>/dev/null)$(tput setaf 250 2>/dev/null)" || info_color=""
    error_color="$(tput setab 232 2>/dev/null)$(tput setaf 160 2>/dev/null)" || error_color=""
    debug_color="${info_color}"
    reset_color="$(tput sgr0 2>/dev/null)" || reset_color=""
fi


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

dot::output::help() {
    local topic="${1:-}" usage="" description=""
    case "${topic}" in
        ""|help|-h|--help)
            printf '%s\n' 'Usage: dot::output <command> [args]' \
                'Format messages, render images and quotes, and inspect terminal dimensions.' \
                '' 'Commands:' \
                '  pretty, level, levels       Format messages and inspect severity levels' \
                '  image, logo                Render images' \
                '  quote, term-quote, figlet   Print plain or decorative text' \
                '  random-font                Select a decorative font name' \
                '  width, height              Print terminal dimensions' \
                '  color-tab, colors256       Display terminal color samples' \
                '  splash, splash-info        Display a splash or system information' \
                '' 'Use dot::output help <command> for options and prerequisites.'
            return 0 ;;
        pretty)
            usage='pretty [-c] [-e] [-t] [-l LEVEL] [--] MESSAGE'
            description='Format a message. Known levels: info (default), error, debug; custom labels retain unknown-level rendering.' ;;
        level) usage='level <info|error|debug>'; description='Print a colored severity label.' ;;
        levels) usage='levels'; description='List supported severity levels.' ;;
        image) usage='image [options] [--] [IMAGE]'; description='Render with chafa; bare filenames are also searched in data/images.' ;;
        logo) usage='logo'; description='Render a random iCloud JPEG; requires find, shuf, and jp2a.' ;;
        quote) usage='quote'; description='Select a short quote from data/quotes.yaml; requires yq and shuf.' ;;
        term-quote) usage='term-quote'; description='Render a quote using optional figlet and lolcat, with plain-text fallback.' ;;
        figlet) usage='figlet MESSAGE [true|false] [FIGLET_OPTIONS...]'; description='Render text with figlet; the second argument enables optional lolcat color.' ;;
        random-font) usage='random-font'; description='Print a decorative font name.' ;;
        width|height) usage="${topic}"; description='Print terminal size, falling back to COLUMNS/LINES and then 80x24.' ;;
        color-tab) usage='color-tab'; description='Display 256 background colors; requires tput.' ;;
        colors256) usage='colors256 [bg|fg]'; description='Display ANSI background (default) or foreground colors.' ;;
        splash) usage='splash [--no-image] [--no-quote] [--no-info]'; description='Display a splash; DOT_SPLASH_IMAGE_EXCLUDE defaults to gif.' ;;
        splash-info) usage='splash-info'; description='Print host, shell, uptime, and optional tmux/git information.' ;;
        *) printf 'dot::output help: unknown command: %s\n' "${topic}" >&2; return 1 ;;
    esac
    printf 'Usage: dot::output %s\n       dot::output::%s\n\n%s\n' "${usage}" "${usage}" "${description}"
    case "${topic}" in
        pretty)
            printf '%s\n' '' 'Options:' \
                '  -c, --color          Enable color' \
                '  -e, --emoji          Enable emoji' \
                '  -t, --timestamp      Include a timestamp' \
                '  -l, --level LEVEL    Select severity (default: info)' \
                '' 'Example: dot::output pretty --level error "Build failed"' ;;
        image)
            printf '%s\n' '' 'Options:' \
                '  --format FORMAT      Chafa format (default: symbols)' \
                '  --symbols SYMBOLS    Symbol set (default: block+border)' \
                '  --size WIDTHxHEIGHT  Output size (default: automatic)' \
                '  --colors MODE        Chafa color mode (default: chafa default)' \
                '  --list               List images without requiring chafa' \
                '  --random             Select an image from data/images' \
                '' 'Example: dot::output image --size 80x24 photo.jpg' ;;
    esac
    printf '\n%s\n' 'Help: -h, --help (before operands). Returns 0 on success, nonzero on failure.'
}

dot::output() {
    local action="${1:-help}"
    [[ $# -gt 0 ]] && shift
    case "${action}" in
        help|-h|--help) dot::output::help "$@" ;;
        pretty) dot::output::pretty "$@" ;;
        level) dot::output::level "$@" ;;
        levels) dot::output::levels "$@" ;;
        image) dot::output::image "$@" ;;
        logo) dot::output::logo "$@" ;;
        quote) dot::output::quote "$@" ;;
        term-quote) dot::output::term-quote "$@" ;;
        figlet) dot::output::figlet "$@" ;;
        random-font) dot::output::random-font "$@" ;;
        width) dot::output::width "$@" ;;
        height) dot::output::height "$@" ;;
        color-tab) dot::output::color-tab "$@" ;;
        colors256) dot::output::colors256 "$@" ;;
        splash) dot::output::splash "$@" ;;
        splash-info) dot::output::splash-info "$@" ;;
        *) printf 'dot::output: unknown command: %s (use dot::output help)\n' "${action}" >&2; return 1 ;;
    esac
}

function dot::output::color-tab() {
    case "${1:-}" in -h|--help) dot::output::help color-tab; return ;; esac
    command -v tput >/dev/null 2>&1 || { printf '%s\n' 'dot::output::color-tab: tput is required' >&2; return 1; }
    local i=0
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
    case "${1:-}" in -h|--help) dot::output::help levels; return ;; esac
    local output="" level=""
    for level in "${levels[@]}"; do
        output+="${level} "
    done
    echo "${output}"
}

function dot::output::level() {
    case "${1:-}" in -h|--help) dot::output::help level; return ;; esac
    local level="${1:-}"
    if [[ -z "${level}" ]]; then
        echo "Usage: dot::output::level <level>" >&2
        return 1
    fi

    case "${level}" in
        info|error|debug) ;;
        *) printf 'Invalid level: %s. Available levels: info error debug\n' "${level}" >&2; return 1 ;;
    esac

    case "${level}" in
        info) echo "${info_color}info${reset_color}" ;;
        error) echo "${error_color}error${reset_color}" ;;
        debug) echo "${debug_color}debug${reset_color}" ;;
        *) echo "${reset_color}unknown${reset_color}" ;;
    esac
}


function dot::output::pretty() {
    local message="" level="" color=0 emoji=0 timestamp=0 output=""
    local OPTIND=1 OPTARG="" opt=""
    local -a normalized_args=()

    output=""

    # t="$(date +%Y-%d-%m.%H.%M.%S)"

    level="info"  # default level
    color=0
    emoji=0
    timestamp=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help) normalized_args+=(-h); shift ;;
            --color) normalized_args+=(-c); shift ;;
            --emoji) normalized_args+=(-e); shift ;;
            --timestamp) normalized_args+=(-t); shift ;;
            --level|-l)
                if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == -* ]]; then
                    printf 'dot::output::pretty: %s requires a level\n' "$1" >&2
                    return 1
                fi
                normalized_args+=(-l "$2"); shift 2 ;;
            --level=) printf '%s\n' 'dot::output::pretty: --level requires a level' >&2; return 1 ;;
            --level=*) normalized_args+=(-l "${1#*=}"); shift ;;
            --) normalized_args+=("$@"); break ;;
            --*) printf 'Invalid option: %s\n' "$1" >&2; return 1 ;;
            -*) normalized_args+=("$1"); shift ;;
            *) normalized_args+=("$@"); break ;;
        esac
    done
    set -- "${normalized_args[@]}"
    while getopts ":hectl:" opt; do
        case ${opt} in
            h) dot::output::help pretty; return ;;
            e) emoji=1 ;;
            c) color=1 ;;
            t) timestamp=1;;
            l) level="${OPTARG}" ;;
            \?) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
            :) echo "Option -$OPTARG requires an argument." >&2; return 1 ;;
        esac
    done

    shift $((OPTIND - 1))
    message="${1:-}"
    if [[ -z "${message}" ]]; then
        echo "Usage: dot::output::pretty [-c] [-e] [-t] [-l <level>] <message>" >&2
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
    case "${1:-}" in -h|--help) dot::output::help logo; return ;; esac
    local tool="" images="" image="" width=""
    for tool in find shuf jp2a; do
        command -v "${tool}" >/dev/null 2>&1 || { printf 'dot::output::logo: %s is required\n' "${tool}" >&2; return 1; }
    done
    [[ -d "${ICLOUD:-}/dot/shell/images" ]] || { printf '%s\n' 'dot::output::logo: iCloud image directory not found' >&2; return 1; }
    images="$(find "${ICLOUD}/dot/shell/images" -type f -name '*.jpg')" || return $?
    [[ -n "${images}" ]] || { printf '%s\n' 'dot::output::logo: no JPEG images found' >&2; return 1; }
    image="$(printf '%s\n' "${images}" | shuf -n 1)" || return $?
    width="$(dot::output::width)" || return $?
    jp2a --colors --width="$(( width / 3 ))" --border --color-depth=24 --background=dark "${image}"
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
    case "${1:-}" in -h|--help) dot::output::help random-font; return ;; esac
	local fonts=(
		"cyberlarge"
		"elite"
		"bloody"
		"roman"
		"jacky"
		"rusto"
		"ascii12"
		"binary"
	)
    local offset=0
    [[ -n "${ZSH_VERSION:-}" ]] && offset=1
    echo "${fonts[$((RANDOM % ${#fonts[@]} + offset))]}"
}

function dot::output::quote() {
	case "${1:-}" in -h|--help) dot::output::help quote; return ;; esac
	local _quote="" tool=""
	for tool in yq shuf; do
		command -v "${tool}" >/dev/null 2>&1 || { printf 'dot::output::quote: %s is required\n' "${tool}" >&2; return 1; }
	done
	_quote="$(yq '.[] | .text + " -- " + .author | select(length < 45)' "${DOT_DIRECTORY}/data/quotes.yaml")" || return $?
	printf '%s\n' "${_quote}" | shuf -n1
}

dot::output::_colorize() {
    if command -v lolcat >/dev/null 2>&1; then
        printf '%s\n' "$1" | lolcat
    else
        printf '%s\n' "$1"
    fi
}

function dot::output::term-quote() {
    case "${1:-}" in -h|--help) dot::output::help term-quote; return ;; esac
    local quote=""
    if ! command -v figlet >/dev/null 2>&1; then
        quote="$(dot::output::quote)" || return $?
        dot::output::_colorize "${quote}"
        return $?
    fi
    local tool=""
    for tool in yq shuf; do
        command -v "${tool}" >/dev/null 2>&1 || { printf 'dot::output::term-quote: %s is required\n' "${tool}" >&2; return 1; }
    done

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

    quote="$(yq ".[] | .text + \" -- \" + .author | select(length < ${max_len})" \
        "${DOT_DIRECTORY}/data/quotes.yaml")" || return $?
    quote="$(printf '%s\n' "${quote}" | shuf -n1)" || return $?

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
            dot::output::_colorize "${rendered}"
            return $?
        fi
    done

    # Absolute fallback: plain lolcat output
    dot::output::_colorize "${quote}"
}

function dot::output::figlet() {
    case "${1:-}" in -h|--help) dot::output::help figlet; return ;; --) shift ;; esac
    [[ $# -gt 0 && -n "$1" ]] || { printf '%s\n' 'Usage: dot::output::figlet MESSAGE [true|false] [FIGLET_OPTIONS...]' >&2; return 1; }
    local message="$1" color="${2:-false}" rendered="" count=$#
    shift
    [[ $# -gt 0 ]] && shift
    echo "${count}"
    if command -v figlet >/dev/null 2>&1; then
        if [[ $# -gt 0 ]]; then
            rendered="$(printf '%s\n' "${message}" | figlet "$@")" || return $?
        else
            rendered="$(figlet "${message}")" || return $?
        fi
    else
        rendered="${message}"
    fi
    if [[ "${color}" == true ]]; then
        dot::output::_colorize "${rendered}"
    else
        printf '%s\n' "${rendered}"
    fi
}

function dot::output::height () {
	case "${1:-}" in -h|--help) dot::output::help height; return ;; esac
	local dimensions="" height="${LINES:-24}"
	if dimensions="$(stty size 2>/dev/null)"; then
		height="${dimensions%% *}"
	fi
	case "${height}" in ''|*[!0-9]*|0) height=24 ;; esac
	printf '%s\n' "${height}"
}

function dot::output::width () {
	case "${1:-}" in -h|--help) dot::output::help width; return ;; esac
	local dimensions="" width="${COLUMNS:-80}"
	if dimensions="$(stty size 2>/dev/null)"; then
		width="${dimensions##* }"
	fi
	case "${width}" in ''|*[!0-9]*|0) width=80 ;; esac
	printf '%s\n' "${width}"
}

function dot::output::colors256() {
    case "${1:-}" in -h|--help) dot::output::help colors256; return ;; esac
    local row col blockrow blockcol red green blue
    local showcolor=""
    case "${1:-bg}" in
        bg) showcolor=dot::output::_color256-bg ;;
        fg) showcolor=dot::output::_color256-fg ;;
        *) printf '%s\n' 'dot::output::colors256: expected bg or fg' >&2; return 1 ;;
    esac
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


function dot::output::image() {
    # Display an image in the terminal using chafa
    # Usage: dot::output::image [options] [image]
    #   image         filename or path (searches data/images by default)
    #   --format F    chafa format (default: symbols)
    #   --symbols S   symbol set (default: block+border)
    #   --size WxH    output size, e.g. 80x24 (default: auto)
    #   --colors N    color mode: 2/8/16/256/full (default: full)
    #   --list        list available images in data/images
    #   --random      display a random image from data/images
    #   --help|-h     show this help

    local format="symbols"
    local symbols="block+border"
    local size=""
    local colors=""
    local image=""
    local image_dir="${DOT_DIRECTORY}/data/images"
    local list_mode=0
    local random_mode=0

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --format|--symbols|--size|--colors)
                if [[ $# -lt 2 || -z "${2:-}" || "${2:-}" == --* ]]; then
                    printf 'dot::output::image: %s requires a value\n' "$1" >&2
                    return 1
                fi
                case "$1" in
                    --format) format="$2" ;;
                    --symbols) symbols="$2" ;;
                    --size) size="$2" ;;
                    --colors) colors="$2" ;;
                esac
                shift 2 ;;
            --list)    list_mode=1; shift ;;
            --random)  random_mode=1; shift ;;
            --help|-h)
                dot::output::help image; return ;;
            --)
                shift
                [[ $# -le 1 && -z "${image}" ]] || { printf '%s\n' 'dot::output::image: expected one image' >&2; return 1; }
                image="${1:-}"; break ;;
            -*)
                echo "dot::output::image: unknown option: $1" >&2
                return 1 ;;
            *)
                [[ -z "${image}" ]] || { printf '%s\n' 'dot::output::image: expected one image' >&2; return 1; }
                image="$1"; shift ;;
        esac
    done
    if (( list_mode + random_mode > 1 )) || { (( list_mode || random_mode )) && [[ -n "${image}" ]]; }; then
        printf '%s\n' 'dot::output::image: choose an image, --list, or --random' >&2
        return 1
    fi

    # --list mode
    if [[ "${list_mode}" -eq 1 ]]; then
        if [[ -d "${image_dir}" ]]; then
            local entries="" tool=""
            for tool in find basename sort; do
                command -v "${tool}" >/dev/null 2>&1 || { printf 'dot::output::image: %s is required for --list\n' "${tool}" >&2; return 1; }
            done
            entries="$(find "${image_dir}" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.tiff' \) -exec basename {} \;)" || return $?
            [[ -n "${entries}" ]] || return 0
            printf '%s\n' "${entries}" | sort
            return $?
        else
            echo "dot::output::image: image directory not found: ${image_dir}" >&2
            return 1
        fi
    fi

    # --random mode
    if [[ "${random_mode}" -eq 1 ]]; then
        command -v shuf >/dev/null 2>&1 || { printf '%s\n' 'dot::output::image: shuf is required for --random' >&2; return 1; }
        if [[ ! -d "${image_dir}" ]]; then
            echo "dot::output::image: image directory not found: ${image_dir}" >&2
            return 1
        fi
        image="$(find "${image_dir}" -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.tiff' \))" || return $?
        image="$(printf '%s\n' "${image}" | shuf -n1)" || return $?
        if [[ -z "${image}" ]]; then
            echo "dot::output::image: no images found in ${image_dir}" >&2
            return 1
        fi
    fi

    # Resolve image path
    if [[ -z "${image}" ]]; then
        echo "dot::output::image: no image specified (use --help for usage)" >&2
        return 1
    fi

    # If not an absolute/relative path with directory component, search data/images
    if [[ "${image}" != */* && ! -f "${image}" ]]; then
        if [[ -f "${image_dir}/${image}" ]]; then
            image="${image_dir}/${image}"
        else
            echo "dot::output::image: file not found: ${image}" >&2
            echo "  searched: ${image_dir}/" >&2
            return 1
        fi
    fi

    if [[ ! -f "${image}" ]]; then
        echo "dot::output::image: file not found: ${image}" >&2
        return 1
    fi

    # Build chafa command
    command -v chafa &>/dev/null || {
        echo "dot::output::image: chafa not found (brew install chafa)" >&2
        return 1
    }
    local -a cmd=(chafa --format="${format}" --symbols "${symbols}")
    [[ -n "${size}" ]] && cmd+=(--size "${size}")
    [[ -n "${colors}" ]] && cmd+=(--colors "${colors}")
    cmd+=(-- "${image}")

    "${cmd[@]}"
}


function dot::output::splash-info() {
    case "${1:-}" in -h|--help) dot::output::help splash-info; return ;; esac
    # Render a compact system info block (4-5 lines, colorized)
    local cyan="\033[0;36m"
    local green="\033[0;32m"
    local yellow="\033[0;33m"
    local magenta="\033[0;35m"
    local dim="\033[2m"
    local reset="\033[0m"

    # Line 1: user@host · shell version
    local shell_version="${ZSH_VERSION:-${BASH_VERSION:-unknown}}"
    local shell_name="zsh"
    [[ -n "${BASH_VERSION:-}" ]] && shell_name="bash"
    printf "  ${cyan}%s${dim}@${cyan}%s${reset} · ${green}%s %s${reset}\n" \
        "${USER}" "$(hostname -s)" "${shell_name}" "${shell_version}"

    # Line 2: uptime · load average
    local uptime_str=""
    if [[ -f /proc/uptime ]]; then
        local _secs
        _secs="$(cut -d' ' -f1 /proc/uptime | cut -d. -f1)"
        local _days=$(( _secs / 86400 ))
        local _hours=$(( (_secs % 86400) / 3600 ))
        local _mins=$(( (_secs % 3600) / 60 ))
        uptime_str="${_days}d ${_hours}h ${_mins}m"
    else
        uptime_str="$(uptime | sed 's/.*up *//' | sed 's/,.*//' | xargs)"
    fi
    local load_str=""
    load_str="$(uptime | awk -F'load averages?: ' '{print $2}' | cut -d, -f1 | xargs)"
    printf "  ${yellow}↑ %s${reset} · ${yellow}load %s${reset}\n" \
        "${uptime_str}" "${load_str}"

    # Line 3: tmux sessions (if tmux available)
    if command -v tmux &>/dev/null; then
        local tmux_count=0
        tmux_count="$(tmux ls 2>/dev/null | wc -l | xargs)"
        if [[ "${tmux_count}" -gt 0 ]]; then
            local tmux_names=""
            tmux_names="$(tmux ls 2>/dev/null | cut -d: -f1 | paste -sd ',' - | sed 's/,/, /g')"
            printf "  ${magenta}tmux${reset} ${dim}(%s):${reset} %s\n" \
                "${tmux_count}" "${tmux_names}"
        else
            printf "  ${magenta}tmux${reset} ${dim}(no active sessions)${reset}\n"
        fi
    fi

    # Line 4: git branch + repo (if in a repo)
    if git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
        local repo_name=""
        repo_name="$(basename "$(git rev-parse --show-toplevel 2>/dev/null)")"
        local branch=""
        branch="$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)"
        printf "  ${green}⎇ %s${reset} ${dim}(%s)${reset}\n" "${branch}" "${repo_name}"
    fi
}


function dot::output::splash() {
    # Terminal splash screen: chafa image (top) + system info + figlet quote (bottom)
    # Usage: dot::output::splash [--no-image] [--no-quote] [--no-info]
    #
    # Env vars:
    #   DOT_SPLASH_IMAGE_EXCLUDE  comma-separated extensions to skip (default: "gif")

    local show_image=1
    local show_info=1
    local show_quote=1

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-image) show_image=0; shift ;;
            --no-quote) show_quote=0; shift ;;
            --no-info)  show_info=0; shift ;;
            --help|-h)
                dot::output::help splash; return ;;
            --) shift; [[ $# -eq 0 ]] && break
                printf '%s\n' 'dot::output::splash: no operands expected' >&2; return 1 ;;
            *) printf 'dot::output::splash: unknown option: %s\n' "$1" >&2; return 1 ;;
        esac
    done

    local term_width="" ret=0
    term_width="$(dot::output::width)"

    # --- Image ---
    if [[ "${show_image}" -eq 1 ]]; then
        if command -v chafa &>/dev/null; then
            local image_dir="${DOT_DIRECTORY}/data/images"
            local exclude="${DOT_SPLASH_IMAGE_EXCLUDE:-gif}"

            # Build find exclusion arguments from comma-separated list
            local -a find_args=("${image_dir}" -type f)
            find_args+=(\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.bmp' -o -iname '*.tiff' -o -iname '*.gif' \))

            # Remove excluded extensions from results via grep -v
            local grep_pattern=""
            local ext=""
            while [[ -n "${exclude}" ]]; do
                ext="${exclude%%,*}"
                if [[ "${exclude}" == *,* ]]; then exclude="${exclude#*,}"; else exclude=""; fi
                ext="$(echo "${ext}" | xargs)"
                [[ -n "${ext}" ]] && grep_pattern="${grep_pattern:+${grep_pattern}|}\.${ext}$"
            done

            local selected_image=""
            if [[ -n "${grep_pattern}" ]]; then
                selected_image="$(find "${find_args[@]}" 2>/dev/null | grep -ivE "${grep_pattern}" | shuf -n1)"
            else
                selected_image="$(find "${find_args[@]}" 2>/dev/null | shuf -n1)"
            fi

            if [[ -n "${selected_image}" ]]; then
                local img_height=12
                # Scale height for very narrow terminals
                (( term_width < 60 )) && img_height=8
                (( term_width < 40 )) && img_height=5

                chafa --format=symbols --symbols block+border \
                    --size "${term_width}x${img_height}" \
                    "${selected_image}" || ret=$?
                echo ""
            fi
        fi
    fi

    # --- System Info ---
    if [[ "${show_info}" -eq 1 ]]; then
        dot::output::splash-info || ret=$?
        echo ""
    fi

    # --- Quote ---
    if [[ "${show_quote}" -eq 1 ]]; then
        dot::output::term-quote || ret=$?
    fi
    return "${ret}"
}
