#!/bin/bash

set -eu
PULLREQUEST=$1

checkout='ConcordanceCheck'
pipeline='ConcordanceCheck'

TMPDIRECTORY='/groups/umcg-atd/tmp07'
WORKDIR="${TMPDIRECTORY}/tmp/${pipeline}/betaAutotest"
TEMP="${WORKDIR}/temp"

## cleanup data to get new data
echo "cleaning up.."
rm -rvf "${WORKDIR}/${pipeline}"

	echo "new pull request for ConcordanceCheck"
	rm -rf "${WORKDIR}"
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
	echo "checkout commit: COMMIT"
	git checkout -f "${COMMIT}"

	mv nextflow ../

## copy samplesheets to ${TMPDIRECTORY}/samplesheets/
cp -v "${WORKDIR}/${pipeline}/nextflow/test/samplesheets/"*".sampleId.txt" "${WORKDIR}/samplesheets/"

rm -rf "${WORKDIR}/logs/${pipeline}"

echo "Now starting the pipeline"
module load ${pipeline}/betaAutotest

"${WORKDIR}"/ConcordanceCheck/bin/ConcordanceCheck.sh -g umcg-atd -w "${WORKDIR}"

echo -e "\n Test succeeded!!\n"
fi
