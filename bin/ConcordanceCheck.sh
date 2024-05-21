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

umask 0027

# Env vars.
export TMPDIR="${TMPDIR:-/tmp}" # Default to /tmp if $TMPDIR was not defined.
SCRIPT_NAME="$(basename "${0}")"
SCRIPT_NAME="${SCRIPT_NAME%.*sh}"
INSTALLATION_DIR="$(cd -P "$(dirname "${0}")/.." && pwd)"
LIB_DIR="${INSTALLATION_DIR}/lib"
CFG_DIR="${INSTALLATION_DIR}/etc"
HOSTNAME_SHORT="$(hostname -s)"
ROLE_USER="$(whoami)"
REAL_USER="$(logname 2>/dev/null || echo 'no login name')"

#
##
### Functions.
##
#

if [[ -f "${LIB_DIR}/sharedFunctions.bash" && -r "${LIB_DIR}/sharedFunctions.bash" ]]
then
	# shellcheck source=lib/sharedFunctions.bash
	source "${LIB_DIR}/sharedFunctions.bash"
else
	printf '%s\n' "FATAL: cannot find or cannot access sharedFunctions.bash"
	exit 1
fi

function showHelp() {
	#
	# Display commandline help on STDOUT.
	#
	cat <<EOH
======================================================================================================================
Script to calculate concordance between SNV calls from NGS and Array data.

Usage:

	$(basename "${0}") OPTIONS

Options:

	-h	Show this help.
	-g	group
	-l	Log level.
		Must be one of TRACE, DEBUG, INFO (default), WARN, ERROR or FATAL.

Config and dependencies:

	This script needs 3 config files, which must be located in ${CFG_DIR}:
		1. <group>.cfg     for the group specified with -g
		2. <host>.cfg        for this server. E.g.:"${HOSTNAME_SHORT}.cfg"
		3. sharedConfig.cfg  for all groups and all servers.
	In addition the library sharedFunctions.bash is required and this one must be located in ${LIB_DIR}.

======================================================================================================================

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
while getopts ":g:l:	h" opt
do
	case "${opt}" in
		h)
			showHelp
			;;
		g)
			GROUP="${OPTARG}"
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
if [[ -z "${GROUP:-}" ]]
then
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' 'Must specify a group with -g'
fi

#
# Source config files.
#
log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Sourcing config files ..."
declare -a configFiles=(
	"${CFG_DIR}/${GROUP}.cfg"
	"${CFG_DIR}/${HOSTNAME_SHORT}.cfg"
	"${CFG_DIR}/sharedConfig.cfg"
	"${CFG_DIR}/ConcordanceCheck.cfg"
	"${HOME}/molgenis.cfg"
)

for configFile in "${configFiles[@]}"; do
	if [[ -f "${configFile}" && -r "${configFile}" ]]
	then
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

#
# Make sure to use an account for cron jobs and *without* write access to prm storage.
#

if [[ "${ROLE_USER}" != "${ATEAMBOTUSER}" ]]
then
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "This script must be executed by user ${ATEAMBOTUSER}, but you are ${ROLE_USER} (${REAL_USER})."
fi

lockFile="${TMP_ROOT_DIR}/logs/${SCRIPT_NAME}.lock"
thereShallBeOnlyOne "${lockFile}"
log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Successfully got exclusive access to lock file ${lockFile} ..."
log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Log files will be written to ${TMP_ROOT_DIR}/logs ..."

concordanceCheckVersion=$(module list | grep -o -P 'ConcordanceCheck(.+)')
module list

concordanceDir="/groups/${GROUP}/${TMP_LFS}/concordance/"

# header format of .sampleId.txt
##data1Id	data2Id	location1	location2	fileType1	fileType2	build1	build2	processStepId

while IFS= read -r sampleSheet
do
	log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Processing samplesheet ${sampleSheet} ..."
	filePrefix="$(basename "${sampleSheet}" .sampleId.txt)"
	concordanceCheckId="${filePrefix}"
	controlFileBase="${concordanceDir}/logs/concordance/"
	export JOB_CONTROLE_FILE_BASE="${controlFileBase}/${filePrefix}.${SCRIPT_NAME}"
	# shellcheck disable=SC2174
	mkdir -m 2770 -p "${controlFileBase}"
	mkdir -p "${concordanceDir}/jobs/${concordanceCheckId}"
	log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "TEST ls ${concordanceDir}/jobs/${concordanceCheckId}/${concordanceCheckId}.sh"

	if [[ ! -f "${concordanceDir}/jobs/${concordanceCheckId}.sh" ]]
	then
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "${concordanceDir}/jobs/${concordanceCheckId}/${concordanceCheckId}.sh FOUND"

		printf '' > "${JOB_CONTROLE_FILE_BASE}.started"

		data1Id=$(sed 1d "${sampleSheet}" | awk 'BEGIN {FS="\t"}{print $1}')
		data2Id=$(sed 1d "${sampleSheet}" | awk 'BEGIN {FS="\t"}{print $2}')
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Calculating concordance over ${data1Id} compared to ${data2Id}."
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Output file name: ${concordanceCheckId}."

cat << EOH > "${concordanceDir}/jobs/${concordanceCheckId}/${concordanceCheckId}.sh"
#!/bin/bash
#SBATCH --job-name=Concordance_${concordanceCheckId}
#SBATCH --output=${concordanceDir}/jobs/${concordanceCheckId}/${concordanceCheckId}.out
#SBATCH --error=${concordanceDir}/jobs/${concordanceCheckId}/${concordanceCheckId}.err
#SBATCH --time=00:30:00
#SBATCH --cpus-per-task 1
#SBATCH --mem 6gb
#SBATCH --open-mode=append
#SBATCH --export=NONE
#SBATCH --get-user-env=60L

set -o  pipefail
set -eu

# Env vars.
export TMPDIR="${TMPDIR:-/tmp}" # Default to /tmp if "${TMPDIR}" was not defined.
SCRIPT_NAME="$(basename "${0}")"
SCRIPT_NAME="${SCRIPT_NAME%.*sh}"
INSTALLATION_DIR="$(cd -P "$(dirname "${0}")/.." && pwd)"
LIB_DIR="${INSTALLATION_DIR}/lib"
CFG_DIR="${INSTALLATION_DIR}/etc"
HOSTNAME_SHORT="$(hostname -s)"
ROLE_USER="$(whoami)"
REAL_USER="$(logname 2>/dev/null || echo 'no login name')"

#
##
### Functions.
##
#
if [[ -f "${LIB_DIR}/sharedFunctions.bash" && -r "${LIB_DIR}/sharedFunctions.bash" ]]
then
	# shellcheck source=lib/sharedFunctions.bash
	source "${LIB_DIR}/sharedFunctions.bash"
else
	printf '%s\n' "FATAL: cannot find or cannot access sharedFunctions.bash"
	exit 1
fi
	module load "${ConcordanceCheckVersion}"
	module load "${nextflowVersion}"

	"${EBROOTNEXTFLOW}/nextflow" run "${EBROOTCONCORDANCECHECK}/nextflow/main.nf" \\
	--samplesheet "${sampleSheet}" \\
	-work-dir "${concordanceDir}/tmp/" \\
	--output "${concordanceDir}/results/" \\
	-profile slurm \\
	|| {
			log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" "0" " Concordance pipeline crashed. Check ${concordanceDir}/jobs/${concordanceCheckId}.out"
			tail -50 "${concordanceDir}/jobs/${concordanceCheckId}/${concordanceCheckId}.out" >> "${JOB_CONTROLE_FILE_BASE}.started"
			mv -v "${JOB_CONTROLE_FILE_BASE}."{started,failed}
			exit 1
			}

	echo "${concordanceCheckVersion}" > "${concordanceDir}/results/${concordanceCheckId}.ConcordanceCheckVersion"

	if [[ -e "${JOB_CONTROLE_FILE_BASE}.started" ]]
	then
		mv "${JOB_CONTROLE_FILE_BASE}."{started,finished}
	else
		touch "${JOB_CONTROLE_FILE_BASE}.finished"
	fi

	mv "${concordanceDir}/jobs/${concordanceCheckId}/${concordanceCheckId}.sh."{started,finished}
EOH
	fi

	if [[ ! -f "${concordanceDir}/jobs/${concordanceCheckId}/${concordanceCheckId}.sh.started" ]] && [[ ! -f "${concordanceDir}/jobs/${concordanceCheckId}/${concordanceCheckId}.sh.finished" ]]
	then
		cd "${concordanceDir}/jobs/${concordanceCheckId}"
		sbatch "${concordanceCheckId}.sh"
		sleep 3
		touch "${concordanceCheckId}.sh.started"
		cd -
	fi
done < <(find "${concordanceDir}/samplesheets/" -maxdepth 1 -type f -iname "*sampleId.txt")

# Clean exit.
#
log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Finished successfully."
trap - EXIT
exit 0
