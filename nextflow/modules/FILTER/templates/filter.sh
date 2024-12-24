#!/bin/bash

set -o pipefail
set -eu

    sampleId="!{meta.dataId}"

    bcftools filter -e "INFO/DP < !{params.minimalDP}" "!{file}" | bcftools sort > "!{sampleId}.!{meta.build}.DPfiltered.vcf"
    bgzip -c "!{sampleId}.!{meta.build}.DPfiltered.vcf" > "!{sampleId}.!{meta.build}.DPfiltered.vcf.gz"