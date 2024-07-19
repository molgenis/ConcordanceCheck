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

	#check if reheadering is needed.
	sampleName=$(bcftools query -l "!{sampleId}.called.sorted.vcf.gz")
	if [[ "${sampleName}" != "!{sampleId}" ]]
	then
		echo "Reheadering. Replace ${sampleName} for !{sampleId}."
		echo -e "${sampleName} !{sampleId}" > rename.txt
		bcftools reheader -s rename.txt -o "!{sampleId}.called.sorted.reheader.vcf.gz" "!{sampleId}.called.sorted.vcf.gz"
		mv "!{sampleId}.called.sorted.reheader.vcf.gz" "!{sampleId}.called.sorted.vcf.gz"
	else
		echo "no reheadering needed."
	fi