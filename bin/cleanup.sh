#!/bin/bash

#
##
### Environment and Bash sanity.
##
#
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]
then
	echo "Sorry, you need at least bash 4.x to use ${0}." >&2
	exit 1
fi

set -e # Exit if any subcommand or pipeline returns a non-zero exit status.
set -u # Raise exception if variable is unbound. Combined with set -e will halt execution when an unbound variable is encountered.
set -o pipefail # Fail when any command in series of piped commands failed as opposed to only when the last command failed.

umask 0027

# Env vars.
export TMPDIR="${TMPDIR:-/tmp}" # Default to /tmp if $TMPDIR was not defined.
SCRIPT_NAME="$(basename "${0}")"
SCRIPT_NAME="${SCRIPT_NAME%.*sh}"
INSTALLATION_DIR="$(cd -P "$(dirname "${0}")/.." && pwd)"
LIB_DIR="${INSTALLATION_DIR}/lib"
CFG_DIR="${INSTALLATION_DIR}/etc"
HOSTNAME_SHORT="$(hostname -s)"

#
##
### Functions.
##
#
if [[ -f "${LIB_DIR}/sharedFunctions.bash" && -r "${LIB_DIR}/sharedFunctions.bash" ]]; then
	# shellcheck source=lib/sharedFunctions.bash
	source "${LIB_DIR}/sharedFunctions.bash"
else
	printf '%s\n' "FATAL: cannot find or cannot access sharedFunctions.bash"
	trap - EXIT
	exit 1
fi

function showHelp() {
	#
	# Display commandline help on STDOUT.
	#
	cat <<EOH
===============================================================================================================
Script to check the status of the pipeline and emails notification
Usage:
	$(basename "${0}") OPTIONS
Options:
	-h	Show this help.
	-g	Group.
	-n	Dry-run: Do not perform actual removal, but only print the remove commands instead.
	-e	Enable email notification. (Disabled by default.)
	-l	Log level.
		Must be one of TRACE, DEBUG, INFO (default), WARN, ERROR or FATAL.
Config and dependencies:
	This script needs 3 config files, which must be located in ${CFG_DIR}:
	1. <group>.cfg       for the group specified with -g
	2. <host>.cfg        for this server. E.g.:"${HOSTNAME_SHORT}.cfg"
	3. sharedConfig.cfg  for all groups and all servers.
	In addition the library sharedFunctions.bash is required and this one must be located in ${LIB_DIR}.
===============================================================================================================
EOH
	trap - EXIT
	exit 0
}

#
##
### Main.
##
#


#
# Get commandline arguments.
#
log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Parsing commandline arguments ..."
declare group=''
declare dryrun=''
while getopts "g:l:nh" opt; do
	case "${opt}" in
		h)
			showHelp
			;;
		g)
			group="${OPTARG}"
			;;
		n)
			dryrun='-n'
			;;
		l)
			l4b_log_level="${OPTARG^^}"
			l4b_log_level_prio="${l4b_log_levels["${l4b_log_level}"]}"
			;;
		\?)
			log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Invalid option -${OPTARG}. Try $(basename "${0}") -h for help."
			;;
		:)
			log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Option -${OPTARG} requires an argument. Try $(basename "${0}") -h for help."
			;;
		*)
			log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Unhandled option. Try $(basename "${0}") -h for help."
			;;
	esac
done


#
# Check commandline options.
#
if [[ -z "${group:-}" ]]; then
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' 'Must specify a group with -g.'
fi
if [[ -n "${dryrun:-}"  ]]; then
	echo -e "\n\t\t #### Enabled dryrun option for cleanup ##### \n"
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' 'Enabled dryrun option for cleanup.'
	l4b_log_level="DEBUG"
	l4b_log_level_prio=${l4b_log_levels[${l4b_log_level}]}

else
	dryrun="no"
fi

#
# Source config files.
#
log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Sourcing config files ..."
declare -a configFiles=(
	"${CFG_DIR}/${group}.cfg"
	"${CFG_DIR}/${HOSTNAME_SHORT}.cfg"
	"${CFG_DIR}/sharedConfig.cfg"
	"${CFG_DIR}/ConcordanceCheck.cfg"
)
for configFile in "${configFiles[@]}"; do
	if [[ -f "${configFile}" && -r "${configFile}" ]]; then
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Sourcing config file ${configFile} ..."
		#
		# In some Bash versions the source command does not work properly with process substitution.
		# Therefore we source a first time with process substitution for proper error handling
		# and a second time without just to make sure we can use the content from the sourced files.
		#
		# Disable shellcheck code syntax checking for config files.
		# shellcheck source=/dev/null
		mixed_stdouterr=$(source "${configFile}" 2>&1) || log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" "${?}" "Cannot source ${configFile}."
		# shellcheck source=/dev/null
		source "${configFile}"  # May seem redundant, but is a mandatory workaround for some Bash versions.
	else
		log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "Config file ${configFile} missing or not accessible."
	fi
done

module load "${nextflowVersion}"
concordanceDir="/groups/${group}/${TMP_LFS}/concordance/"

##cleaning up files older than 30 days in PROJECTS and TMP when files are copied
while IFS= read -r i
do
	ConcordanceID=$(basename "${i}" .sampleId.txt)
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "${ConcordanceID}"
	sampleId1=$(sed 1d "${i}" | awk 'BEGIN {FS="\t"}{print $2}')
	sampleId2=$(sed 1d "${i}" | awk 'BEGIN {FS="\t"}{print $1}')
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' \
	"check ${ConcordanceID}, sampleId1:${sampleId1} and sampleId2:${sampleId1}"

	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' \
	"finished file: /groups/${group}/${TMP_LFS}/logs/concordance/${ConcordanceID}.ConcordanceCheck.finished"

	if [[ -f "/groups/${group}/${TMP_LFS}/logs/concordance/${ConcordanceID}.ConcordanceCheck.finished" ]]
	then
		if [[ -d "${concordanceDir}/jobs/${ConcordanceID}" ]]
		then
			cd "${concordanceDir}/jobs/${ConcordanceID}" || true ;nextflow clean -n || true;cd ..
		fi
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' \
			"rm -rf ${concordanceDir}/results/${ConcordanceID}.*
			rm -rf /groups/${group}/${TMP_LFS}/logs/concordance/${ConcordanceID}.*
			rm -rf ${concordanceDir}/ngs/${sampleId1}.*
			rm -rf ${concordanceDir}/ngs/${sampleId2}.*
			rm -rf ${concordanceDir}/jobs/${ConcordanceID}/"
		if [[ "${dryrun}" == "no" ]]
		then
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "No dryrun."
		if [[ -d "${concordanceDir}/jobs/${ConcordanceID}" ]]
		then
			cd "${concordanceDir}/jobs/${ConcordanceID}" || true ;nextflow clean -f || true;cd ..
		fi
			rm -rf "${concordanceDir}/results/${ConcordanceID}."*
			rm -rf "/groups/${group}/${TMP_LFS}/logs/concordance/${ConcordanceID}."*
			rm -rf "${concordanceDir}/ngs/${sampleId1}."*
			rm -rf "${concordanceDir}/ngs/${sampleId2}."*
			rm -rf "${concordanceDir}/jobs/${ConcordanceID}/"
		fi
	else
		echo "Nothing done."
	fi
done < <(find "${TMP_ROOT_DIR}/concordance/samplesheets/archive/" -maxdepth 1 -type f -mtime +30 -exec ls -d {} \;)

log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' 'Finished successfully!'

trap - EXIT
exit 0
