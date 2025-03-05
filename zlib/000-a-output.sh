#% author: Aaron Samuel
#% description: shell output functions
# shellcheck shell=bash

#** disable relevant shellcheck warnings **#
# shellcheck source=/dev/null
# shellcheck disable=SC2207

# if [[ "${DOT_CONFIGURE_OUTPUT}" -eq 0 ]]; then
#     return
# fi

if [[ "${DOT_DEBUG:-0}" -eq 1 ]]; then
    echo "loading: ${DOT_LIBRARY} (${DOT_DIRECTORY})"
fi

if [[ "${DOT_DISABLE_OUTPUTS}" -eq 1 ]]; then
    return
fi

function availableColorTab() {
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

function printSuccess() {
    local message="${1}"
    printf "$(tput setab 238)$(tput setaf 002) ok! 🚀  [%s] %s $(tput sgr0)\n" "$(date +%Y-%d-%m.%H.%M.%S)" "${message}"
}

function printError() {
    local message="${1}"
    printf "$(tput setab 232)$(tput setaf 160) error! 💣  [%s] %s $(tput sgr0)\n" "$(date +%Y-%d-%m.%H.%M.%S)" "${message}"
}

function printDebug() {
    local message="${1}"
    printf "$(tput setab 238)$(tput setaf 250) debug! 🛠️  [%s] %s $(tput sgr0)\n" "$(date +%Y-%d-%m.%H.%M.%S)" "${message}"
}

function printAttribute() {
	local key="${1}"
	local value="${2}"
	printf "$(tput setab 236)$(tput setaf 002)$(tput bold)%s: $(tput sgr0) $(tput setab 242)$(tput setaf 021)$(tput smul)%s$(tput rmul)$(tput sgr0)\n"	"$key" "$value"
}

function termLogo() {
	# find "${ICLOUD}/dot/shell/images" -type f -name "*.jpg" | shuf -n 1 | xargs -I {} jp2a --colors --term-fit --width="$(( $(terminalWidth) / 2 ))" -b {}
    find "${ICLOUD}/dot/shell/images" -type f -name "*.jpg" | shuf -n 1 | xargs -I {} jp2a --colors --width="$(( $(terminalWidth) / 3 ))" --border --color-depth=24 --background=dark {}
}

function termImage () {
    local image="${1}"
    TERM=screen-256color "$HOME"/.iterm2/imgcat "${image}"
    sleep 5
    export TERM=xterm-256color
    # echo "hi"
}


function termRandomFont() {
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

function randomQuote() {
	randomQuote="$(
		jq -r '. | map("\(.text) -- \(.author)")| .[] |select(length < 45)' "${DOT_DIRECTORY}/data/quotes.json" |shuf -n1
	)"
	echo "${randomQuote}"
}

function termQuote() {
	# can we do random selection of fonts?
	randomQuote="$(
		jq -r '. | map("\(.text) -- \(.author)")| .[] |select(length < 45)' "${DOT_DIRECTORY}/data/quotes.json" |shuf -n1
	)"
	# echo "${randomQuote}" | figlet -p -w "$(terminalWidth)" -d "${HOME}/.figlet" -f "$(termRandomFont "${@}")" -k -l| lolcat
    echo "${randomQuote}" | figlet -p -w "$(( $(terminalWidth)  ))" -d "${HOME}/.figlet" -f "$(termRandomFont "${@}")" -k -l| lolcat
}

function toFiglet() {
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
	# echo "args: ${args}"
	# if [[ "${color}" == "true" ]]; then
	# 		echo "$message" | figlet "$args"| lolcat
	# fi
	# if [[ ! "${color}" == "true" ]]; then
	# 		echo "$message" | figlet "$args"
	# fi


}

function terminalHeight () {
	stty size | cut -d' ' -f1
}

function terminalWidth () {
	stty size | cut -d' ' -f2
}

function showcolors256() {
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

function _showcolor256_fg() {
    local code
    code=$(printf %03d "$1")
    echo -ne "\033[38;5;${code}m"
    echo -nE " $code "
    echo -ne "\033[0m"
}

function _showcolor256_bg() {
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
