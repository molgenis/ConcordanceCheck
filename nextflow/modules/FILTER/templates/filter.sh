#!/bin/bash

set -o pipefail
set -eu

    sampleId="!{meta.dataId}"

    bcftools filter -e "INFO/DP < !{params.minimalDP}" "!{file}" > "!{sampleId}.!{params.build}.DPfiltered.vcf"
    bgzip -c "!{sampleId}.!{params.build}.DPfiltered.vcf" > "!{sampleId}.!{params.build}.DPfiltered.vcf.gz"