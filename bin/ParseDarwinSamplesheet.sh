#!/bin/bash

# executed by the umcg-gd-ateambot, part of the ConcordanceCheck.


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
Scripts to make automatically a samplesheet for the concordance check between ngs and array data and pushes the ngs and 
array data to the destination machine.
ngs.vcf should be in /groups/${NGSGROUP}/${PRM_LFS}/concordance/ngs/.
array.vcf should be in /groups/${ARRAYGROUP}/${PRM_LFS}/concordance/array/.


Usage:

	$(basename "${0}") OPTIONS

Options:

	-h	Show this help.
	-g	ngsgroup (the group which runs the script and countains the ngs.vcf files, umcg-gd).
	-a	arraygroup (the group where the array.vcf files are, umcg-gap )
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

array_contains () {
	local array="$1[@]"
	local seeking="${2}"
	local in=1
	for element in "${!array-}"; do
		if [[ "${element}" == "${seeking}" ]]; then
			in=0
			break
		fi
	done
	return "${in}"
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
while getopts ":g:a:l:h" opt
do
	case "${opt}" in
		h)
			showHelp
			;;
		g)
			NGSGROUP="${OPTARG}"
			;;
		a)
			ARRAYGROUP="${OPTARG}"
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
			;;	esac
done

#
# Check commandline options.
#
if [[ -z "${NGSGROUP:-}" ]]
then
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' 'Must specify a ngs-group with -g. For the ngs.vcf files'
fi

if [[ -z "${ARRAYGROUP:-}" ]]
then
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' 'Must specify an array-group with -a. for the array.vcf files'
fi
#
# Source config files.
#
log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME:-main}" '0' "Sourcing config files ..."
declare -a configFiles=(
	"${CFG_DIR}/${NGSGROUP}.cfg"
	"${CFG_DIR}/${HOSTNAME_SHORT}.cfg"
	"${CFG_DIR}/sharedConfig.cfg"
	"${CFG_DIR}/ConcordanceCheck.cfg"
	"${HOME}/molgenis.cfg"
)

for configFile in "${configFiles[@]}"
do
	if [[ -f "${configFile}" && -r "${configFile}" ]]
	then
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Sourcing config file ${configFile} ..."
		#
		# In some Bash versions the source command does not work properly with process substitution.
		# Therefore we source a first time with process substitution for proper error handling
		# and a second time without just to make sure we can use the content from the sourced files.
		#
		# Disable shellcheck code syntax checking for config files.
		# shellcheck source=/dev/null
		mixed_stdouterr=$(source "${configFile}" 2>&1) || log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" "${?}" "Cannot source ${configFile}."
		# shellcheck source=/dev/null
		source "${configFile}"  # May seem redundant, but is a mandatory workaround for some Bash versions.
	else
		log4Bash 'FATAL' "${LINENO}" "${FUNCNAME[0]:-main}" '1' "Config file ${configFile} missing or not accessible."
	fi
done

#
# Make sure to use an account for cron jobs and *without* write access to prm storage.
#

if [[ "${ROLE_USER}" != "${ATEAMBOTUSER}" ]]
then
	log4Bash 'FATAL' "${LINENO}" "${FUNCNAME:-main}" '1' "This script must be executed by user ${ATEAMBOTUSER}, but you are ${ROLE_USER} (${REAL_USER})."
fi

# shellcheck disable=SC2029
## ervanuit gaande dat de filename samplename.txt heet, 
#kolom 1: ook de samplename is 
#kolom 2: projectNaam NGS 
#kolom 3: DNA nummer NGS
#kolom 4: projectnaam array
#kolom 5: DNA nummer array

mapfile -t sampleSheetsDarwin < <(find "/groups/${GROUP}/${DAT_LFS}/ConcordanceCheckSamplesheets/" -maxdepth 1 -type f -name '*.csv')
if [[ "${#sampleSheetsDarwin[@]}" -eq '0' ]]
then
	log4Bash 'WARN' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "No sample sheets found @ /groups/${GROUP}/${DAT_LFS}/ConcordanceCheckSamplesheets/: There is nothing to do."
	trap - EXIT
	exit 0
else
	for darwinSamplesheet in "${sampleSheetsDarwin[@]}"
	do
		
		< "${darwinSamplesheet}" sed 's/\r/\n/g' | sed "/^[\s,]*$/d" > "${darwinSamplesheet}.converted"
		mv "${darwinSamplesheet}"{.converted,}
		samplesheetName="$(basename "${darwinSamplesheet}" ".csv")"
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Processing sample sheet: ${darwinSamplesheet} ..."
		projectNGS=$(awk '{print $2}' "${darwinSamplesheet}")
		dnaNGS=$(awk '{print $3}' "${darwinSamplesheet}")
		projectArray=$(awk '{print $4}' "${darwinSamplesheet}")
		dnaArray=$(awk '{print $5}' "${darwinSamplesheet}")
		ngsVcf=()
		arrayVcf=()
		# shellcheck disable=SC2207
		ngsPath=("/groups/${NGSGROUP}/prm0"*"/projects/${projectNGS}"*"/run01/results/variants/")
		if [[ -e "${ngsPath[0]}" ]]
		then
			mapfile -t ngsVcf < <(find "/groups/${NGSGROUP}/prm0"*"/projects/"*"${projectNGS}"*"/run01/results/variants/" -maxdepth 1 -name "*${dnaNGS}*.vcf.gz")
			if [[ "${#ngsVcf[@]}" -eq '0' ]]
			then
				log4Bash 'WARN' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "/groups/${GROUP}/*prm0*/projects/${projectNGS}*/run*/results/variants/*${dnaNGS}*.vcf.gz NOT FOUND! skipped"
				continue
			else
				log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Found back NGS ${ngsVcf[0]}"
				ngsVcfId=$(basename "${ngsVcf[0]}" ".final.vcf.gz")
			fi
		else
			log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "The NGS project folder cannot be found: /groups/${NGSGROUP}/prm0*/projects/${projectNGS}*/run01/results/variants/"
			continue
		fi
		# shellcheck disable=SC2207
		arrayPath=("/groups/${ARRAYGROUP}/prm0"*"/projects/"*"${projectArray}"*"/run01/results/vcf/")
		if [[ -e "${arrayPath[0]}" ]]
		then
			mapfile -t arrayVcf < <(find "/groups/${ARRAYGROUP}/prm0"*"/projects/"*"${projectArray}"*"/run01/results/vcf" -maxdepth 1  -name "${dnaArray}*.vcf")

			if [[ "${#arrayVcf[@]}" -eq '0' ]]
			then
				log4Bash 'WARN' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "/groups/${ARRAYGROUP}/prm0*/projects/*${projectArray}*/run*/results/vcf/${dnaArray}*.vcf NOT FOUND! skipped"
				continue
			else
				log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Found back Array: ${arrayVcf[0]}"
				arrayId="$(basename "${arrayVcf[0]}" .FINAL.vcf)"
			fi
		else
			log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "The ARRAY project folder cannot be found: /groups/${ARRAYGROUP}/prm0*/projects/*${projectArray}*/run01/results/"
			continue
		fi
		host_prm=$(hostname -s)

		#rsync data to tmp
		rsync -av "${arrayVcf[0]}" "${HOSTNAME_TMP}:/groups/${GROUP}/${TMP_LFS}/concordance/array/"
		rsync -av "${ngsVcf[0]}" "${HOSTNAME_TMP}:/groups/${GROUP}/${TMP_LFS}/concordance/ngs/"

		# shellcheck disable=SC2029	
		ssh "${HOSTNAME_TMP}" "echo -e \"data1Id\tdata2Id\tlocation1\tlocation2\n${arrayId}\t${ngsVcfId}\t${host_prm}:${arrayVcf[0]}\t${host_prm}:${ngsVcf[0]}\" > \"/groups/${GROUP}/${TMP_LFS}/concordance/samplesheets/${samplesheetName}.sampleId.txt\""
		log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "samplesheet created on ${HOSTNAME_TMP}: /groups/${GROUP}/${TMP_LFS}/concordance/samplesheets/${samplesheetName}.sampleId.txt"
		
		mv "${darwinSamplesheet}" "/groups/${GROUP}/${DAT_LFS}/ConcordanceCheckSamplesheets/archive/"
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "moved ${darwinSamplesheet} to /groups/${GROUP}/${DAT_LFS}/ConcordanceCheckSamplesheets/archive/"

	done
fi
trap - EXIT
exit 0


