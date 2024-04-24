#!/bin/bash

set -o pipefail
set -eu

	#create tabix file, and bgzip if needed.
	for vcf in "!{vcf1}" "!{vcf2}"
	do
		if [[ "${vcf}" != *".gz" ]]
		then
			bgzip -c "${vcf}" > "${vcf}".gz
			vcf="${vcf}.gz"
		fi
		tabix -f -p vcf "${vcf}"
	done

	## create samplesheet
	mappingfile="!{id}_!{meta[0].dataId}_!{meta[1].dataId}.sampleId.txt"
	echo -e "data1Id\tdata2Id\tlocation1\tlocation2" > "${mappingfile}"
	echo -e "!{meta[0].dataId}\t!{meta[1].dataId}\t!{vcf1}\t!{vcf2}" >> "${mappingfile}"

	# run concordancecheck
	java -XX:ParallelGCThreads="!{task.cpus}" \
	-Djava.io.tmpdir="!{params.tmpDir}" \
	"-Xmx!{task.memory.toMega() - 256}m" \
	-jar "${EBROOTCOMPAREGENOTYPECALLS}/CompareGenotypeCalls.jar" \
	-d1 "!{vcf1}" \
	-D1 VCF \
	-d2 "!{vcf2}" \
	-D2 VCF \
	-ac \
	--sampleMap "${mappingfile}" \
	-o "!{id}"_"!{meta[0].dataId}"_"!{meta[1].dataId}" \
	-sva
