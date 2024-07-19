#!/bin/bash

set -o pipefail
set -eu

	#create tabix file, and bgzip if needed.
	vcf1="!{vcf1}"
	vcf2="!{vcf2}"
	if [[ "${vcf1}" != *".gz" ]]
	then
		bgzip -c "${vcf1}" > "${vcf1}".gz
		vcf1="${vcf1}.gz"
	fi
	if [[ "${vcf2}" != *".gz" ]]
	then
		bgzip -c "${vcf2}" > "${vcf2}".gz
		vcf2="${vcf2}.gz"
	fi
	tabix -f -p vcf "${vcf1}"
	tabix -f -p vcf "${vcf2}"

	## create samplesheet
	mappingfile="!{id}_!{meta[0].dataId}_!{meta[1].dataId}.sampleId.txt"
	echo -e "data1Id\tdata2Id\tlocation1\tlocation2" > "${mappingfile}"
	echo -e "!{meta[0].dataId}\t!{meta[1].dataId}\t${vcf1}\t${vcf2}" >> "${mappingfile}"

	# run concordancecheck
	java -XX:ParallelGCThreads="!{task.cpus}" \
	-Djava.io.tmpdir="!{params.tmpDir}" \
	"-Xmx!{task.memory.toMega() - 256}m" \
	-jar "${EBROOTCOMPAREGENOTYPECALLS}/CompareGenotypeCalls.jar" \
	-d1 "${vcf1}" \
	-D1 VCF \
	-d2 "${vcf2}" \
	-D2 VCF \
	-ac \
	--sampleMap "${mappingfile}" \
	-o "!{meta[0].fileprefix}" \
	-sva

	if [[ $(wc -l <"!{meta[0].fileprefix}.sample") -ne 2 ]]
	then
		echo "something when wrong during concordance check."
		exit 1
	else
		echo "Concordance check done."
	fi
