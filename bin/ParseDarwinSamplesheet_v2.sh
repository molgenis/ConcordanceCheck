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

fetch () {	
# gets a sampleId, a extention and searchPatch and reruns the filename, full filepath. 
local _sample="$1"
local _extention="$2"
local _searchPath="$3"

	if [[ -e "${_searchPath[0]}" ]]
	then
		mapfile -t _files < <(find "${_searchPath}" -maxdepth 1 -name "*${_sample}*${_extention}" )
		if [[ "${#_files[@]}" -eq '0' ]]
		then
			log4Bash 'WARN' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "${_searchPath}/*${_sample}*${_extention} NOT FOUND! skipped"
			continue
		else
			log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Found back  ${_files[0]}"
			_filePath="${_files[0]}"
		fi
	else
		log4Bash 'WARN' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "${_searchPath} NOT FOUND! skipped"
		continue
	fi	

#return _sampleId and _filePath
return "${_filePath}"

}

fetch_data () {
	local _project="$1"
	local _sample="${2}"
	local _type="${3}"
	local _filePath=""
	local _fileType=""
	local _sampleId=""

	local _prefix=$(echo "${_project}" | awk -F '_' 'print $1') 

	if [[ "${_prefix}" =~ ^(NGS|NGSR|QXTR|XHTS|MAGR|QXT|HSR|GS)$ ]] && [[ "${_type}" == "DNA" ]]
	then
		_searchPath=("/groups/${NGSGROUP}/prm0"*"/projects/${_project}"*"/run01/results/concordanceCheckSnps/")
		if [[ -e "${_searchPath[0]}" ]]
		then
			#fetch filename and path, and store in ${_sampleId} ${_filePath}, set _fileType to VCF
			_filePath=$(fetch "${_sample}" ".concordanceCheckCalls.vcf" "${_searchPath}")
			_sampleId=$(basename "${_filePath}" ".concordanceCheckCalls.vcf")
			_fileType='VCF'

		elif [[ ! -e "${_searchPath[0]}" ]]
		then
			log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "VCF not found, Try fetching CRAM."
			_searchPath=("/groups/${NGSGROUP}/prm0"*"/projects/${_project}"*"/run01/results/alignment/")
			
			#fetch filename and path, and store in ${_sampleId} ${_filePath}, set _fileType to CRAM
			_filePath=$(fetch "${_sample}" ".merged.dedup.bam.cram" "${_searchPath}")
			_sampleId=$(basename "${_filePath}" ".merged.dedup.bam.cram")
			_fileType='CRAM'
		else
			log4Bash 'WARN' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "VCF not found, CRAM not found."
		fi
	elif [[ "$_project" == "GS_"* ]] && [[ "${_type}" == "RNA" ]]
	then
	
		_searchPath=("/groups/${NGSGROUP}/prm0"*"/projects/${_project}"*"/run01/results/variants/concordance/")
		#fetch filename and path, and store in ${_sampleId} ${_filePath}, set _fileType to VCF
		_filePath=$(fetch "${_sample}" ".concordance.vcf.gz" "${_searchPath}")
		_sampleId=$(basename "${_filePath}" ".concordance.vcf.gz")
		_fileType='VCF'
	
	elif [[ "${_project}" == "APAR_"* ]]
	then
		_searchPath=("/groups/${ARRAYGROUP}/dat0"*"/openarray/"*"${_project}"*"/")

		#fetch filename and path, and store in ${_sampleId} ${_filePath}, set _fileType to OA
		_filePath=$(fetch "${_sample}" ".oarray.txt" "${_searchPath}")
		_sampleId=$(basename "${_filePath}" ".oarray.txt")
		_fileType='OPENARRAY'

	elif [[ "${_project}" == "LRS_"* ]]
	then
		arrayPath=("/groups/${NGSGROUP}/prm0"*"/project/"*"${_project}"*"/run01/results/alignments/")

		#fetch filename and path, and store in ${_sampleId} ${_filePath}, set _fileType to OA
		_filePath=$(fetch "${_sample}" ".cram" "${_searchPath}")
		_sampleId=$(basename "${_filePath}" ".cram")
		_fileType='CRAM'
	else
		log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "The project folder 	${_project} ${_sample} ${_type} cannot be found anywhere."
	fi

	echo "${_sampleId} ${_project} ${_filePath} ${_fileType}"
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
#  example filename: processStepID_project1_sample1_project2_sample2.csv
#  example content   658059	HSR_195	DNA12345	DNA	GRCh37	OPAR-12	DNA12345	DNA	GRCh38

#kolom 1: processStepID
#kolom 2: projectNaam 1
#kolom 3: DNA nummer 2 
#kolom 4: Material 1
#kolom 5: GenomeBuild 1
#kolom 6: projectNaam 2
#kolom 7: DNA nummer 2 
#kolom 8: Material 2
#kolom 9: GenomeBuild 2

#mapfile -t sampleSheetsDarwin < <(find "/groups/${GROUP}/${DAT_LFS}/ConcordanceCheckSamplesheets/Opar" -maxdepth 1 -type f -name '*.csv')
mapfile -t sampleSheetsDarwin < <(find "/groups/${NGSGROUP}/dat06/ConcordanceCheckSamplesheets/Opar" -maxdepth 1 -type f -name '*.csv')

if [[ "${#sampleSheetsDarwin[@]}" -eq '0' ]]
then
	log4Bash 'WARN' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "No sample sheets found @ /groups/${GROUP}/${DAT_LFS}/ConcordanceCheckSamplesheets/: There is nothing to do."
	trap - EXIT
	exit 0
else
	for darwinSamplesheet in "${sampleSheetsDarwin[@]}"
	do
		< "${darwinSamplesheet}" sed 's/\r/\n/g' | sed "/^[\s,]*$/d" > "${darwinSamplesheet}.converted"
		darwinSamplesheet="${darwinSamplesheet}.converted"
		samplesheetName="$(basename "${darwinSamplesheet}" ".csv.converted")"
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Processing sample sheet: ${darwinSamplesheet} ..."

		processStepID=$(awk '{print $1}' "${darwinSamplesheet}")
		project1=$(awk '{print $2}' "${darwinSamplesheet}")
		sample1=$(awk '{print $3}' "${darwinSamplesheet}")
		sampleType1=$(awk '{print $4}' "${darwinSamplesheet}")
		genomebuild1=$(awk '{print $5}' "${darwinSamplesheet}")
		project2=$(awk '{print $6}' "${darwinSamplesheet}")
		sample2=$(awk '{print $7}' "${darwinSamplesheet}")
		sampleType2=$(awk '{print $8}' "${darwinSamplesheet}")
		genomebuild2=$(awk '{print $9}' "${darwinSamplesheet}")

		host_prm=$(hostname -s)

		read _sampleId _project _filePath _fileType < <(fetch_data ${project1} ${sample1} ${sampleType1})
		echo "${_sampleId} ${_project} ${_filePath} ${_fileType}"

		#rsync data to tmp
#		rsync -av "${arrayVcf[0]}" "${HOSTNAME_TMP}:/groups/${GROUP}/${TMP_LFS}/concordance/array/"
#		rsync -av "${ngsVcf[0]}" "${HOSTNAME_TMP}:/groups/${GROUP}/${TMP_LFS}/concordance/ngs/"

		# shellcheck disable=SC2029	
#		ssh "${HOSTNAME_TMP}" "echo -e \"data1Id\tdata2Id\tlocation1\tlocation2\n${arrayId}\t${ngsVcfId}\t${host_prm}:${arrayVcf[0]}\t${host_prm}:${ngsVcf[0]}\" > \"/groups/${GROUP}/${TMP_LFS}/concordance/samplesheets/${samplesheetName}.sampleId.txt\""
#		log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "samplesheet created on ${HOSTNAME_TMP}: /groups/${GROUP}/${TMP_LFS}/concordance/samplesheets/${samplesheetName}.sampleId.txt"
		
		#copy original darwinSamplesheet to archive and remove the .converted one
#		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "moving ${darwinSamplesheet%.converted} to /groups/${GROUP}/${DAT_LFS}/ConcordanceCheckSamplesheets/archive/ "
#		mv -v "${darwinSamplesheet%.converted}" "/groups/${GROUP}/${DAT_LFS}/ConcordanceCheckSamplesheets/archive/"
#		rm -v "${darwinSamplesheet}"
	done
fi
trap - EXIT
exit 0


