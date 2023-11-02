#!/usr/local/bin/bash

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
	find "${HOME}/.terminal_images" -type f -name "*.jpg" | shuf -n 1 | xargs -I {} jp2a --colors --width=80 -b {}
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
		jq -r '. | map("\(.text) -- \(.author)")| .[] |select(length < 50)' "${HOME}/.zsh_helpers/quotes.json" |shuf -n1
	)"
	echo "${randomQuote}"
}

function termQuote() {
	# can we do random selection of fonts?
	randomQuote="$(
		jq -r '. | map("\(.text) -- \(.author)")| .[] |select(length < 50)' "${HOME}/.zsh_helpers/quotes.json" |shuf -n1
	)"
	echo "${randomQuote}" | figlet -p -w "$(terminalWidth)" -d "${HOME}/.zsh_helpers/figlet-fonts" -f "$(termRandomFont "${@}")" -k -l| lolcat
}

function toFiglet() {
	message="${1}"
	color="${2:-false}"
	shift 2
	args="${*}"


	#echo "args: ${args}"
	if [[ "${color}" == "true" ]]; then
			echo "$message" | figlet "$args"| lolcat
	fi
	if [[ ! "${color}" == "true" ]]; then
			echo "$message" | figlet "$args"
	fi


}
function terminalHeight () {
	stty size | cut -d' ' -f1
}

function terminalWidth () {
	stty size | cut -d' ' -f2
}
