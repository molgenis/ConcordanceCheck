#!/bin/bash

# executed by the umcg-gd-ateambot, part of the ConcordanceCheck.

if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]
then
	echo "Sorry, you need at least bash 4.x to use ${0}." >&2
	exit 1
fi

set -e # Exit if any subcommand or pipeline returns a non-zero exit status.
set -u # Raise exception if variable is unbound. Combined with set -e will halt execution when an unbound variable is encountered.
#shellcheck enable=check-set-e-suppressed

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
ngs projects should be in /groups/${NGSGROUP}/${PRM_LFS}/projects.
array projects should be in /groups/${ARRAYGROUP}/${PRM_LFS}/openarray/.


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
local _sample="${1}"
local _extention="${2}"
local _searchPath="${3}"
local _filePath=""

	if [[ -e "${_searchPath[0]}" ]]
	then
		mapfile -t _files < <(find "${_searchPath}" -maxdepth 1 -regex "${_searchPath}.*${_sample}.*${_extention}" )
		if [[ "${#_files[@]}" -eq '0' ]]
		then
			_filePath="not found"
		else
			_filePath="${_files[0]}"
		fi
	else
		_filePath="not found"
	fi

#return found filePath as _filePath, or 'not found in case of missing file.'
echo "${_filePath}"
}

fetch_data () {
	local _project="${1}"
	local _sample="${2}"
	local _type="${3}"
	local _filePath=""
	local _fileType=""
	local _sampleId=""
	local _prefix=""
	local _projectId=""
	local _postfix=""

	_prefix=$(echo "${_project}" | awk -F '_' '{print $1}')
	_projectId=$(echo "${_project}" | awk -F '-' '{print $1}')
	_postfix=$(echo "${_project}" | awk -F '-' '{print $2}')
	
	if [[ "${_projectId}" =~ [A-Z]$ ]]
	then
		_projectId="${_projectId::-1}"
	fi

	log4Bash 'WARN' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Try to find: /groups/${NGSGROUP}/prm0"*"/projects/${_projectId}"*

	if [[ "${_prefix}" =~ ^(NGS|NGSR|QXTR|XHTS|MAGR|QXT|HSR|GS)$ ]] && [[ "${_type}" =~ ^(WES|WGS)$ ]]
	then
		
		###
		_searchPath=("/groups/${NGSGROUP}/prm0"*"/projects/${_projectId}"*"/run01/results/alignment/")
		if [[ -e "${_searchPath[0]}" ]]
		then

			#fetch filename and path, and store in ${_sampleId} ${_filePath}, set _fileType to CRAM
			_filePath="$(set -e; fetch "${_sample}" "\(.bam\|.bam.cram\)" "${_searchPath[0]}")"
			_sampleId="$(basename "${_filePath}" ".merged.dedup.bam.cram")"
			_sampleId="$(basename "${_sampleId}" ".merged.dedup.bam")"
			if [[ "${_filePath}" == *"cram"* ]]
			then
				_fileType='CRAM'
			else
				_fileType='BAM'
			fi
		elif [[ ! -d "${_searchPath[0]}" ]]
		then
			_searchPath=("/groups/${NGSGROUP}/prm0"*"/projects/${_projectId}"*"/run01/results/concordanceCheckSnps/")
			#fetch filename and path, and store in ${_sampleId} ${_filePath}, set _fileType to VCF
			_filePath="$(set -e; fetch "${_sample}" ".concordanceCheckCalls.vcf" "${_searchPath[0]}")"
			_sampleId="$(basename "${_filePath}" ".concordanceCheckCalls.vcf")"
			_fileType='VCF'

		### later switch vcf before bam.

#		_searchPath=("/groups/${NGSGROUP}/prm0"*"/projects/${_projectId}"*"/run01/results/concordanceCheckSnps/")
#		if [[ -e "${_searchPath[0]}" ]]
#		then
#			#fetch filename and path, and store in ${_sampleId} ${_filePath}, set _fileType to VCF
#			_filePath="$(set -e; fetch "${_sample}" ".concordanceCheckCalls.vcf" "${_searchPath[0]}")"
#			_sampleId="$(basename "${_filePath}" ".concordanceCheckCalls.vcf")"
#			_fileType='VCF'

#		elif [[ ! -d "${_searchPath[0]}" ]]
#		then
#			log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "VCF not found, Try fetching CRAM."
#			_searchPath=("/groups/${NGSGROUP}/prm0"*"/projects/${_project}"*"/run01/results/alignment/")

			#fetch filename and path, and store in ${_sampleId} ${_filePath}, set _fileType to CRAM
#			_filePath="$(set -e; fetch "${_sample}" "\(.bam\|.bam.cram\)" "${_searchPath[0]}")"
#			_sampleId="$(basename "${_filePath}" ".merged.dedup.bam.cram")"
#			_sampleId="$(basename "${_sampleId}" ".merged.dedup.bam")"
#			if [[ "${_filePath}" == *"cram"* ]]
#			then
#				_fileType='CRAM'
#			else
#				_fileType='BAM'
#			fi
		else
			log4Bash 'WARN' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "concordanceCheckSnps VCF not found, CRAM not found."
		fi
	elif [[ "${_project}" == "GS_"* ]] && [[ "${_type}" == "RNASeq" ]]
	then
		_searchPath=("/groups/${NGSGROUP}/prm0"*"/projects/${_projectId}"*"/run01/results/variants/concordance/")

		if [[ -d "${_searchPath[0]}" ]]
		then
			#fetch filename and path, and store in ${_sampleId} ${_filePath}, set _fileType to VCF
			_filePath="$(set -e; fetch "${_sample}" ".concordance.vcf.gz" "${_searchPath[0]}")"
			_sampleId="$(basename "${_filePath}" ".concordance.vcf.gz")"
			_fileType='VCF'

		elif [[ ! -d "${_searchPath[0]}" ]]
		then
			log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "RNA VCF not found, Try fetching BAM."
			_searchPath=("/groups/${NGSGROUP}/prm0"*"/projects/${_projectId}"*"/run01/results/alignment/")

			#fetch filename and path, and store in ${_sampleId} ${_filePath}, set _fileType to CRAM
			_filePath="$(set -e; fetch "${_sample}" ".sorted.merged.bam" "${_searchPath[0]}")"
			_sampleId="$(basename "${_filePath}" ".sorted.merged.bam")"
			_fileType='BAM'
		else
			log4Bash 'WARN' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "concordanceCheckSnps VCF not found, BAM not found for RNA sample."
		fi

	elif [[ "${_project}" == "OPAR_"* ]] && [[ "${_type}" == "OA" ]]
	then
		_searchPath=("/groups/${ARRAYGROUP}/dat0"*"/openarray/"*"${_project}"*"/")

		#fetch filename and path, and store in ${_sampleId} ${_filePath}, set _fileType to OA
		_filePath="$(set -e; fetch "${_sample}" ".oarray.txt" "${_searchPath[0]}")"
		_sampleId="$(basename "${_filePath}" ".oarray.txt")"
		_fileType='OPENARRAY'

	elif [[ "${_project}" == "NP_"* ]] && [[ "${_type}" == "NANOPORE" ]]
	then
		_searchPath=("/groups/${NGSGROUP}/prm0"*"/projects/"*"${_project}"*"/run01/results/intermediates/")

		#fetch filename and path, and store in ${_sampleId} ${_filePath}, set _fileType to OA
		_filePath="$(set -e; fetch "${_sample}" ".cram" "${_searchPath[0]}")"
		_sampleId="$(basename "${_filePath}" ".cram")"
		_fileType='CRAM'
	else
		log4Bash 'WARN' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "The project folder ${_project} ${_sample} ${_type} cannot be found anywhere in ${_searchPath[0]}."
		_sampleId='not found'
		_project='not found'
		_fileType='not found'
		_filePath='not found'
	fi

	# store what could be found back.
	return_array["sampleId"]="${_sampleId}"
	return_array["project"]="${_project}"
	return_array["fileType"]="${_fileType}"
	return_array["filePath"]="${_filePath}"
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
#  example content   658059	HSR_195	DNA12345	DNA	GRCh37	OPAR_12	DNA12345	DNA	GRCh38

#kolom 1: processStepID
#kolom 2: projectNaam 1
#kolom 3: DNA nummer 1
#kolom 4: Material 1
#kolom 5: GenomeBuild 1
#kolom 6: projectNaam 2
#kolom 7: DNA nummer 2
#kolom 8: Material 2
#kolom 9: GenomeBuild 2

# source dir for Darwin created jobfiles
samplesheetsDir="/groups/${NGSGROUP}/${DAT_LFS}/ConcordanceCheckSamplesheets/jobfiles_v3"
mapfile -t sampleSheetsDarwin < <(find "${samplesheetsDir}" -maxdepth 1 -type f -name '*.csv')

if [[ "${#sampleSheetsDarwin[@]}" -eq '0' ]]
then
	log4Bash 'WARN' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "No sample sheets found @ ${samplesheetsDir}: There is nothing to do."
	trap - EXIT
	exit 0
else
	for darwinSamplesheet in "${sampleSheetsDarwin[@]}"
	do

		controlFileBase="/groups/${GROUP}/${DAT_LFS}/logs/concordance/"
		< "${darwinSamplesheet}" sed 's/\r/\n/g' | sed "/^[\s,]*$/d" > "${darwinSamplesheet}.converted"
		darwinSamplesheet="${darwinSamplesheet}.converted"
		samplesheetName="$(basename "${darwinSamplesheet}" ".csv.converted")"
		export JOB_CONTROLE_FILE_BASE="${controlFileBase}/${samplesheetName}.${SCRIPT_NAME}"
		touch "${JOB_CONTROLE_FILE_BASE}.started"

		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "Processing sample sheet: ${darwinSamplesheet} ..."

		# fetch and map info from correct collumns from jobfile.
		processStepID=$(awk '{print $1}' "${darwinSamplesheet}")
		project1=$(awk '{print $2}' "${darwinSamplesheet}")
		sample1=$(awk '{print $3}' "${darwinSamplesheet}")
		sampleType1=$(awk '{print $4}' "${darwinSamplesheet}")
		genomebuild1=$(awk '{print $5}' "${darwinSamplesheet}")
		project2=$(awk '{print $6}' "${darwinSamplesheet}")
		sample2=$(awk '{print $7}' "${darwinSamplesheet}")
		sampleType2=$(awk '{print $8}' "${darwinSamplesheet}")
		genomebuild2=$(awk '{print $9}' "${darwinSamplesheet}")

		declare -A return_array
		# try the fetch FileName, project, fileType,filePaths for sampleId 1
		fetch_data "${project1}" "${sample1}" "${sampleType1}"
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "return from fetch_data for sample ${sample1}: ${return_array[sampleId]}, ${return_array[project]}, ${return_array[fileType]},${return_array[filePath]}"
		sampleId1="${return_array[sampleId]}"
		project1="${return_array[project]}"
		fileType1="${return_array[fileType]}"
		filePath1="${return_array[filePath]}"

		# try the fetch FileName, project, fileType,filePaths for sampleId 2
		fetch_data "${project2}" "${sample2}" "${sampleType2}"
		log4Bash 'DEBUG' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "return from fetch_data for sample ${sample2}: ${return_array[sampleId]}, ${return_array[project]}, ${return_array[fileType]},${return_array[filePath]}"
		sampleId2="${return_array[sampleId]}"
		project2="${return_array[project]}"
		fileType2="${return_array[fileType]}"
		filePath2="${return_array[filePath]}"

		# skip jobfile if one of the files can not be found.
		if [[ "${filePath1}" == 'not found' ]] || [[ "${filePath2}" == 'not found' ]]
		then
			log4Bash 'WARN' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "One of the files could not be found for sample: ${sample1}, run in TRACE mode check... ${return_array[sampleId]}, ${return_array[project]}, ${return_array[fileType]}, ${return_array[filePath]}"
			echo "WARN: One or both of the files could not be found for sample: ${sample1}" > "${JOB_CONTROLE_FILE_BASE}.started"
			mv -v "${JOB_CONTROLE_FILE_BASE}".{started,failed}
			continue
		else

			#rsync file to /groups/${GROUP}/${TMP_LFS}/concordance/tmp/ on ${HOSTNAME_TMP}
			rsync -av --progress --log-file="${JOB_CONTROLE_FILE_BASE}.started" --chmod='Du=rwx,Dg=rsx,Fu=rw,Fg=r,o-rwx' "${filePath1}" "${HOSTNAME_TMP}:/groups/${GROUP}/${TMP_LFS}/concordance/ngs/"
			rsync -av --progress --log-file="${JOB_CONTROLE_FILE_BASE}.started" --chmod='Du=rwx,Dg=rsx,Fu=rw,Fg=r,o-rwx' "${filePath2}" "${HOSTNAME_TMP}:/groups/${GROUP}/${TMP_LFS}/concordance/ngs/"

			fileTmpDir="/groups/${GROUP}/${TMP_LFS}/concordance/ngs/"
			fileName1="$(basename "${filePath1}")"
			fileName2="$(basename "${filePath2}")"

			#create concondanceCheck mapping file
			#filename structure example:

			#${processStepId}_${project1}_${sampleId1}_${project2}_${sampleId2}.sampleId.txt

			#Mapping file content example:

			#data1Id	data2Id	location1	location2	fileType1	fileType2	build1	build2	project1	project2	fileprefix	processStepId
			#${sampleId1}	${sampleId2}	${filePath1}/${sampleId1}.extention	${filePath2}/${sampleId2}.extention	VCF|OPENARRAY|BAM|CRAM	VCF|OPENARRAY|BAM|CRAM	CRCh37|CRCh38	CRCh37|CRCh38	project1	project2	jobfilePrefix	processStepId

			# header and content for mappingfile.
			HEADER="data1Id\tdata2Id\tlocation1\tlocation2\tfileType1\tfileType2\tbuild1\tbuild2\tproject1\tproject2\tfileprefix\tprocessStepId"
			CONTENT="${sampleId1}\t${sampleId2}\t${fileTmpDir}/${fileName1}\t${fileTmpDir}/${fileName2}\t${fileType1}\t${fileType2}\t${genomebuild1}\t${genomebuild2}\t${project1}\t${project2}\t${samplesheetName}\t${processStepID}"

			# create mapping file on "${HOSTNAME_TMP}" in /groups/${GROUP}/${TMP_LFS}/concordance/samplesheets/ to be picked up by the concordance pipeline.
			# shellcheck disable=SC2029
			ssh "${HOSTNAME_TMP}" "echo -e \"${HEADER}\n${CONTENT}\" > \"/groups/${GROUP}/${TMP_LFS}/concordance/samplesheets/${samplesheetName}.sampleId.txt\""
			log4Bash 'INFO' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "samplesheet created on ${HOSTNAME_TMP}: /groups/${GROUP}/${TMP_LFS}/concordance/samplesheets/${samplesheetName}.sampleId.txt"

		#copy original darwinSamplesheet to archive and remove the .converted one
		log4Bash 'TRACE' "${LINENO}" "${FUNCNAME[0]:-main}" '0' "moving ${darwinSamplesheet%.converted} to /groups/${GROUP}/${DAT_LFS}/ConcordanceCheckSamplesheets/archive/ "
		mv -v "${darwinSamplesheet%.converted}" "${samplesheetsDir}/archive/"
		rm -f "${JOB_CONTROLE_FILE_BASE}.failed"
		mv -v "${JOB_CONTROLE_FILE_BASE}".{started,finished}
		rm -v "${darwinSamplesheet}"
		fi
	done
fi
log4Bash 'INFO' "${LINENO}" "${FUNCNAME:-main}" '0' "Finished successfully."
trap - EXIT
exit 0
