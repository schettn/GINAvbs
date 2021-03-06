#!/usr/bin/env bash
# shellcheck disable=SC1090

# GINAvbs: A backup solution using git
# (c) 2016-2018 GINAvbs, LLC (https://erebos.xyz/)
# Easy to use backups for configurations, logs and sql files.

# This file is copyright protected under the latest version of the EUPL.
# Please read the LICENSE file for further information.

# This program was initially designed for the Erebos Network.
# If you are neither of those make sure be warned that you use, copy and/or
# modify at your own risk.

# Futhermore it's not recommended to use GINAvbs with a different shell than
# GNU bash version 4.4

# It is highly recommended to use set -eEuo pipefail for every setup script
set -o errexit  # Used to exit upon error, avoiding cascading errors
set -o errtrace # Activate traps to catch errors on exit
set -o pipefail # Unveils hidden failures
set -o nounset  # Exposes unset variables


#### SPECIAL FUNCTIONS #####
# Functions with the purpose of making coding more convenient and
# debugging a bit easier.
# Disclaimer: "SPECIAL FUNCTIONS" are not test functions!
#
# NOTE: SPECIAL FUNCTIONS start with three CAPS letter.
#
# IF YOU ARE AWARE OF A BETTER FORM OF NAMING FEEL FREE TO OPEN A ISSUE
# OTHERWISE PLEASE USE THIS AS A GUIDELINE FOR ANY COMMIT.

EOS_string(){
	# allows to store EOFs in strings
	IFS=$'\n' read -r -d '' $1 || true;
	return $?
} 2>/dev/null


######## GLOBAL VARIABLES AND ENVIRONMENT VARIABLES #########
# For better maintainability, global variables are defined at the top.
# This makes changes easier and lowers the risk of preventable bugs.
#
# GLOBAL variables are written in CAPS
# LOCAL variables start with an underscore
#
# NOTE: Variables starting with a double underscore are read only
#
# IF YOU ARE AWARE OF A BETTER FORM OF NAMING FEEL FREE TO OPEN A ISSUE
# OTHERWISE PLEASE USE THIS AS A GUIDELINE FOR ANY COMMIT

source /etc/os-release # source os release environment variables

# SYSTEM / USER VARIABLES
readonly __DISTRO="${ID}" # get distro id from /etc/os-release
readonly __DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" # workdir
readonly __FILE="${__DIR}/$(basename "${BASH_SOURCE[0]}")" # self
readonly __BASE="$(basename ${__FILE})" # workdir/self
readonly __ROOT="$(cd "$(dirname "${__DIR}")" && pwd)" # homedir

# DEPENDENCY / LOGS VARIABLES
# GINAvbs has currently one dependency that needs to be installed
readonly __GINA_DEPS=(git)
# Location of installation logs
readonly __GINA_LOGS="${__DIR}/install.log"

# SETUP VARIABLES
# Define and set default for enviroment variables
SQL_MODE=${SQL_MODE:-false}

REPOSITORY=${GINA_REPOSITORY:-""}
SSHKEY=${GINA_SSHKEY:-""}
HOST=${GINA_HOST:-""}
USER=${GINA_USER:-""}
PASSWORD=${GINA_PASSWORD:-""}

INTERVAL=${GINA_INTERVAL:-"weekly"}

# COLOR / FORMAT VARIABLES
# Set some colors because without them ain't fun
COL_NC='\e[0m' # default color

COL_LIGHT_GREEN='\e[1;32m' # green
COL_LIGHT_RED='\e[1;31m' # red
COL_LIGHT_MAGENTA='\e[1;95m' # magenta

TICK="[${COL_LIGHT_GREEN}✓${COL_NC}]" # green thick
CROSS="[${COL_LIGHT_RED}✗${COL_NC}]" # red cross
INFO="[i]" # info sign

# shellcheck disable=SC2034
DONE="${COL_LIGHT_GREEN} done!${COL_NC}" # a small motivation ^^
OVER="\\r\\033[K" # back to line start

# LOGO / LICENSE / MANPAGE VARIABLES
# Our temporary logo, might be updated in the future
EOS_string LOGO <<-'EOS'
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
+                      ___________   _____        __                           +
+                     / ____/  _/ | / /   |_   __/ /_  _____                   +
+                    / / __ / //  |/ / /| | | / / __ \/ ___/                   +
+                   / /_/ // // /|  / ___ | |/ / /_/ (__  )                    +
+                   \____/___/_/ |_/_/  |_|___/_.___/____/                     +
+                                                                              +
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
EOS

# Licensing, recommedations and warnings
EOS_string LICENSE <<-'EOS'


+ # GINAvbs: A backup solution using git
+ # (c) 2016-2018 GINAvbs, LLC (https://erebos.xyz/)
+ # Easy to use backups for configurations, logs and sql files.

+ # This file is copyright protected under the latest version of the EUPL.
+ # Please read the LICENSE file for further information.

+ # This program was initially designed for the Erebos Network.
+ # If you are neither of those make sure be warned that you use, copy and/or
+ # modify at your own risk.

+ # Futhermore it's not recommended to use GINAvbs with a different shell than
+ # GNU bash version 4.4
+
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
EOS

# Manual, learn more on our github site
EOS_string MANPAGE <<-'EOS'
+ # Manual:
+
+ # -r --remote "exports to a remote repository"
+ # -i --interval "sets the interval of backups to 15min/daily/hourly/monthly/weekly"
+ # -k --sshkey "deploys a given sshkey"
+ # -s --sql "activates sql mode"
+ # -d --delete "deletes local repo"
+ # -h --help "shows man page"
+
+
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
EOS

# This line serves decorative purposes only
EOS_string COOL_LINE <<-'EOS'
++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
EOS


######## FUNCTIONS #########
# Functions that are part of the core functionality of GINAvbs
#
# FUNCTIONS are written in lowercase
#
# IF YOU ARE AWARE OF A BETTER NAMING SCEME FEEL FREE TO OPEN AN ISSUE
# OTHERWISE PLEASE USE THIS AS A GUIDELINE FOR ANY COMMIT

install() {
	# Install GINAvbs and dependency packages passed in via an argument array
	declare -a _argArray1=(${!1})
	declare -a _installArray=("")

	# Debian based package install - debconf will download the entire package
	# list so we just create an array of any packages missing to
	# cut down on the amount of download traffic.

	for i in "${_argArray1[@]}"; do
		echo -ne "+ ${INFO} Checking for ${i}..."
		if [[ $(which "${i}" 2>/dev/null) ]]; then
			echo -e "+ [${TICK}] Checking for ${i} (is installed)"
		else
			echo -e "+ ${INFO} Checking for ${i} (will be installed)"
			_installArray+=("${i}")
		fi 2>/dev/null
	done

	case ${__DISTRO} in
	'alpine')
		if [[ ${_installArray[@]} ]]; then
			# Installing Packages
			apk add --force ${_installArray[@]}
			# Cleaning cached files
			rm -rf /var/cache/apk/* /var/cache/distfiles/*
			echo -e "+ [${TICK}] All dependencies are now installed"
		fi

		# Placing cron job
		cat <<-EOF > /etc/periodic/${INTERVAL}/ginavbs
			#!/usr/bin/env bash
			echo ""

			# Terminate on errors and output everything to >&2
			set -xe

			cd ${__DIR}

		EOF

		if SQL_MODE; then
			cat <<-'EOF' >> /etc/periodic/${INTERVAL}/ginavbs
				# Commit changes to remote repository
				git pull
				mysqldump --user=root --lock-tables --all-databases > ./dbs.sql
				git add .
				git commit -m "$(date) automated backup (ginavbs)"
				git push --force origin master
			EOF
		else
			cat <<-'EOF' >> /etc/periodic/${INTERVAL}/ginavbs
				# Commit changes to remote repository
				git pull
				git add .
				git commit -m "$(date) automated backup (ginavbs)"
				git push --force origin master
			EOF
		fi

		chmod +x /etc/periodic/${INTERVAL}/ginavbs

		exec "/usr/sbin/crond" "-f" &
	;;
	'arch'|'manjaro')
		if [[ ${_installArray[@]} ]]; then
			# Installing Packages if script was started as root
			if [[ $(pacman -S --noconfirm ${_installArray[@]}) ]]; then
				# Cleaning cached files
				pacman -Scc --noconfirm

			# Installing if sudo is installed
			elif [[ $(sudo pacman -S --noconfirm ${_installArray[@]}) ]]; then
				# Cleaning cached files
				sudo pacman -Scc --noconfirm

			# Try again as root
			else
				echo "+ ${INFO} retry as root again"
				return 43
			fi
			echo -e "+ [${TICK}] All dependencies are now installed"
		fi

	;;
	'debian'|'ubuntu'|'mint'|'kali')
		if [[ ${_installArray[@]} ]]; then
			# Installing Packages if the script was started as root
			if [[ $(apt-get install ${_installArray[@]} -y) ]]; then
				# Cleaning cached files
				apt-get clean -y

			# Installing if sudo is installed
			elif [[ $(sudo apt-get install ${_installArray[@]} -y) ]]; then
				# Cleaning cached files
				sudo apt-get clean -y

			# Try again as root
			else
				echo "+ ${INFO} retry as root again"
				return 43
			fi
			echo -e "+ [${TICK}] All dependencies are now installed"
		fi
		;;
		*) return 1;;
	esac

	return $?
} 2>/dev/null

make_temporary_log() {
	# Create a random temporary file for the log
	TEMPLOG=$(mktemp /tmp/gina_temp.XXXXXX)
	# Open handle 3 for templog
	exec 3>"$TEMPLOG"
	# Delete templog, but allow addressing via file handle
	# This lets us write to the log without having a temporary file on
	# the drive, which is meant to be a security measure so there is no
	# file lingering on the drive during the install process
	rm -f "$TEMPLOG"

	return $?
} 2>/dev/null

copy_to_install_log() {
	# Copy the contents of file descriptor 3 into the install log
	# Since we use color codes such as '\e[1;33m', they should be removed
	sed 's/\[[0-9;]\{1,5\}m//g' < /proc/$$/fd/3 > "${installLogLoc}"
} 2>/dev/null

is_repo() {
	# Check if $1 is a git repository
	if [[ -d "$1/.git" ]]; then
		echo true
	else
		echo false
	fi

	return $?
} 2>/dev/null

make_repo() {
	# Display the message and use the color table to preface the message
	# with an "info" indicator
	echo -ne "+ ${INFO} Create repository in ${__DIR}..."

	# delete everything in it so git can clone into it
	#rm -rf ${__DIR}/*

	git init || true
	
	# Set git username and useremail
	git config user.name "GINAvbs"
	git config user.email "ginavbs@erebos.xyz"

	git remote add origin ${REPOSITORY} || true

	# Print a colored message with a status report
	echo -e "+ [${TICK}] Create repository in ${__DIR}"

	return $?
} 2>/dev/null


update_repo() {
	# Display the message and use the color table to preface the message with
	# an "info" indicator
	echo -ne "+ ${INFO} Update repository in ${__DIR}..."

	git add . || true
	git commit -m "$(date) GINA init (init.sh)" || true

	# Pull the latest commits from master
	git fetch origin || true

	# Pull from and merge with remote repository
	git pull --force \
			 --quiet \
			 --no-edit \
			 --strategy=recursive \
			 --strategy-option=theirs \
			 --allow-unrelated-histories\
			 origin master \
			 || true

	# Push to remote repository
	git push --force \
			 --quiet \
			 --set-upstream \
			 origin master \
			 || true

	# Print a colored message showing it's status
	echo -e "+ [${TICK}] Update repository in ${__DIR}"

	return $?
} 2>/dev/null

nuke_everything() {
	# I am pretty sure there is a better way
	# pls don't push this button

	north_korea_mode=enabled;

	# welp, all local data will be destroyed

	return $?
} 2>/dev/null

manual(){
	# Prints manual
	echo -e "+${COL_LIGHT_GREEN}"
	echo -e "${COL_LIGHT_GREEN}${COOL_LINE}"
	echo -e "+"
	echo -e "${MANPAGE}"
	echo -e "${COL_NC}+"

	return $?
} 2>/dev/null

required_argument(){
	echo "required argument not found for option -$1" 1>/dev/null
	manual

	return $2
} 2>/dev/null

invalid_option(){
	echo "required argument not found for option --$1" 1>/dev/null
	manual

	return $2
} 2>/dev/null

error_handler(){

	echo "+ # ERROR:"
	echo "+"

	case $1 in
	40) echo "+ Bad Request: This function expects at least one Argument!";;
	43) echo "+ Permission Denied: Please try again as root!";;
	44) echo "+ Not Found: Username and Password not found!";;
	51) echo "+ Not Implemented: Please read the Manual, fool!";;
	*)  echo "+ Internal Error: Shit happens! Something has gone wrong.";;
	esac

	echo "+"
	echo "+ error_code $1"

	return $?
} 2>/dev/null

exit_handler(){
	# Copy the temp log file into final log location for storage
	#copy_to_install_log # TODO logging still doesn't working like expected
	local error_code=$?

	if [[ ${error_code} == 0 ]]; then
		echo -e "+"
		echo -e "${COL_LIGHT_MAGENTA}${COOL_LINE}"
		echo -e "+"
		echo "+ Thanks for using GINAvbs"
		echo -e "+"
		echo -e "${COOL_LINE}"

		return ${error_code};
	fi

	echo -e "+"
	echo -e "${COL_LIGHT_RED}${COOL_LINE}"
	echo -e "+"
	error_handler ${error_code}
	echo -e "+"
	echo -e "${COOL_LINE}"

	exit ${error_code}
} 2>/dev/null

######## ENTRYPOINT #########

main(){
	echo -e "${COL_LIGHT_MAGENTA}${LOGO}"
	echo -e "+"
	echo -e "${COL_LIGHT_GREEN}${LICENSE}"
	echo -e "${COL_NC}+"

	set -o xtrace

	# The optional parameters string starting with ':' for silent errors
	local -r _OPTS=':r:i:s:dh-:'
	local -r INVALID_OPTION=51
	local -r INVALID_ARGUMENT=40

	while builtin getopts -- ${_OPTS} opt "$@"; do
		case ${opt} in
		r)    REPOSITORY=${OPTARG}
		;;
		i)    INTERVAL=${OPTARG}
		;;
		k)    SSHKEY=${OPTARG}
		;;
		s)    SQL_MODE=true
		;;
		d)    nuke_everything
		;;
		h)    manual
			  return $?
		;;
		:)    required_argument ${OPTARG} ${INVALID_ARGUMENT}
		;;
		*)    case "${OPTARG}" in
			repository=*)
				REPOSITORY=${OPTARG#*=}
			;;
			repository)
				if ! [[ "${!OPTIND:-'-'}" =~ ^- ]]; then
					REPOSITORY=${!OPTIND};
				else
					required_argument ${OPTARG} ${INVALID_ARGUMENT}
				fi
				OPTIND=$(( ${OPTIND} + 1 ))
			;;
			interval=*)
				INTERVAL=${OPTARG#*=}
			;;
			interval)
				if ! [[ ${!OPTIND:-'-'} =~ ^- ]]; then
					INTERVAL=${!OPTIND};
				else
					required_argument ${OPTARG} ${INVALID_ARGUMENT}
				fi
				OPTIND=$(( ${OPTIND} + 1 ))
			;;
			sshkey=*)
				SSHKEY=${OPTARG#*=}
			;;
			sshkey)
				if ! [[ ${!OPTIND:-'-'} =~ ^- ]]; then
					SSHKEY=${!OPTIND};
				else
					required_argument ${OPTARG} ${INVALID_ARGUMENT}
				fi
				OPTIND=$(( ${OPTIND} + 1 ))
			;;
			sql)
				SQL_MODE=true
			;;
			delete)
				nuke_everything
				return $?
			;;
			help)
				manual
				return $?
			;;
			*)
				invalid_option ${OPTARG} ${INVALID_OPTION}
			;;
			esac
		;;
		esac
	done

	local _tmp=""

	# Strip protocol prefix
	_tmp="${REPOSITORY#*://}"
	# Strip link
	_tmp="${_tmp%%/*}"
	# Get host
	HOST="${_tmp#*@}"
	# Strip host
	_tmp="${_tmp%%@*}"
	# Get username
	USER="${_tmp%%:*}"
	# Get password
	PASSWORD="${_tmp#*:}"

	if [[ ${USER} == ${PASSWORD} ]] && ! [[ ${SSHKEY} ]]; then
		# Check if username or password and/or sshkey was added
		return 44
	fi

	# Install packages used by this installation script
	install __GINA_DEPS[@]

	if ! $(is_repo "${__DIR}") || ! [[ $(ls -A "${__DIR}" 2>/dev/null) ]]; then
		make_repo
	fi

	update_repo

	return $?
}

# Traps everything
trap exit_handler 0 1 2 3 13 15 # EXIT HUP INT QUIT PIPE TERM

make_temporary_log

main "$@" 3>&1 1>&2 2>&3

exit 0
