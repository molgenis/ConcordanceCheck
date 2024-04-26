#!/bin/bash
set -eu
set -o pipefail

    if [[ "!{meta.build}" != "!{params.build}" ]]
    then
        index="!{params.reference.b37}"
        snpbed="!{params.concordanceCheckSnps.b37}"
    else
        index="!{params.reference.b38}"
        snpbed="!{params.concordanceCheckSnps.b38}"
    fi

    samtools index "!{alignmentfile}"

    # Convert openarray file to vcf.
	bcftools mpileup \
	-Ou -f "${index}" \
	"!{alignmentfile}" \
	-R "${snpbed}" \
	| bcftools call \
	-mv -Ob -o "!{sampleId}.converted.vcf"

	echo "Sorting !{sampleId}.converted.vcf"
	bcftools sort "!{sampleId}.converted.vcf" -o "!{sampleId}.converted.sorted.vcf"
    bgzip -c "!{sampleId}.converted.sorted.vcf" > "!{sampleId}.called.sorted.vcf.gz"

 