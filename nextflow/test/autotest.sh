#!/bin/bash

set -eu
PULLREQUEST=$1

#
## functions
#
compare_results_dirs() {
	truth_dir="$1"
	compare_dir="$2"
	error=0  # default: success

	if [[ ! -d "${truth_dir}" || ! -d "${compare_dir}" ]]; then
		echo "One or both directories do not exist."
		return 1
	fi

	for file1 in "${truth_dir}"/*.{sample,variants}; do
		filename=$(basename "${file1}")
		file2="${compare_dir}/${filename}"

		if [ ! -f "${file2}" ]; then
			echo "File ${filename} not found in ${compare_dir}"
			error=1
			continue
		fi

		# Strip first last column from each .sample file before comparing the results
		if [[ "${file1}" == *".sample"* ]];then
			strippedf1="${WORKDIR}/tmp/1.${filename}.stripped"
			strippedf2="${WORKDIR}/tmp/2.${filename}.stripped"
			cut -f2-$(($(head -1 "${file1}" | awk -F'\t' '{print NF}') - 1)) "${file1}" > "${strippedf1}"
			cut -f2-$(($(head -1 "${file2}" | awk -F'\t' '{print NF}') - 1)) "${file2}" > "${strippedf2}"
			file1="${strippedf1}"
			file2="${strippedf2}"
    fi

		if diff -q "${file1}" "${file2}" > /dev/null; then
			echo "${filename} is equal."
		else
			echo "${filename} differs."
			error=1
		fi
	done

return "${error}"
}

#
##main
#

pipeline='ConcordanceCheck'

TMPDIRECTORY='/groups/umcg-atd/tmp07'
WORKDIR="${TMPDIRECTORY}/tmp/${pipeline}/betaAutotest"
TEMP="${WORKDIR}/temp"

## cleanup data to get new data
echo "cleaning up.."
rm -rvf "${WORKDIR}"

echo "new pull request for ConcordanceCheck"
rm -rf "${WORKDIR}/jobs"
rm -rf "${WORKDIR}/results/*"

mkdir -p "${WORKDIR}/jobs"
mkdir -p "${WORKDIR}/results"
mkdir -p "${WORKDIR}/ngs"
mkdir -p "${WORKDIR}/logs/${pipeline}"
mkdir -p "${WORKDIR}/tmp"
mkdir -p "${WORKDIR}/samplesheets/archive"

cd "${WORKDIR}"
git clone "https://github.com/molgenis/${pipeline}.git"

cd "${pipeline}" || exit
git fetch --tags --progress "https://github.com/molgenis/${pipeline}/" +refs/pull/*:refs/remotes/origin/pr/*
COMMIT=$(git rev-parse refs/remotes/origin/pr/${PULLREQUEST}/merge^{commit})
git checkout -f "${COMMIT}"

mv nextflow ../

## copy samplesheets to ${TMPDIRECTORY}/samplesheets/
cp -v "${WORKDIR}/nextflow/test/samplesheets/"*".sampleId.txt" "${WORKDIR}/samplesheets/"

rm -rf "${WORKDIR}/logs/${pipeline}"

echo "Now starting the pipeline"
module load nextflow
module load ${pipeline}/betaAutotest
perl -pi -e 's|sleep 15|sleep 1|g' "${WORKDIR}"/ConcordanceCheck/bin/ConcordanceCheck.sh
"${WORKDIR}"/ConcordanceCheck/bin/ConcordanceCheck.sh -g umcg-atd -w "${WORKDIR}" 2>&1 | tee -a "${WORKDIR}/tmp/ConcordanceCheck.log"

## wait until results files are there

job_ids=($(grep 'Submitted batch job' "${WORKDIR}/tmp/ConcordanceCheck.log" | awk '{print $4}'))
echo "Monitoring ${#job_ids[@]} Slurm jobs..."

# Loop until all jobs are done
all_done=false
while [ "${all_done}" = false ]; do
	all_done=true  # assume done unless we find one that's still running/pending

	for job_id in "${job_ids[@]}"; do
		# Get job state from sacct
		state=$(sacct -j "$job_id" --format=State --noheader | head -n 1 | awk '{print $1}')

		case "${state}" in
			COMPLETED|FAILED|CANCELLED|TIMEOUT|NODE_FAIL)
			echo "Job ${job_id} finished with state: ${state}"
				;;
				"")
					echo "Job ${job_id} not found yet (might still be starting up?)"
					all_done=false
				;;
				*)
					echo "Job ${job_id} is still active with state: $state"
					all_done=false
				;;
		esac
	done

	if [ "${all_done}" = false ]; then
		echo "Waiting 10 seconds before next check..."
		sleep 15
		echo ""
	fi
done

echo "All jobs have finished."

#check output content in trueSet and results dir.
compare_results_dirs "${WORKDIR}/nextflow/test/trueSet/"  "${WORKDIR}/results/"

echo "error $?"
if [ $? -ne 0 ]; then
	echo "At least one file comparison failed!"
	exit 1
else
	echo "Test succeeded!!"
fi