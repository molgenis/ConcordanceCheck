#!/bin/bash
set -o pipefail
set -eu

    sampleId="!{meta.dataId}"
    bcftools norm -d all "!{file}" | bcftools sort >  "!{sampleId}.!{meta.build}.dedup.vcf"
    
    bgzip -c "!{sampleId}.!{meta.build}.dedup.vcf" > "!{sampleId}.!{meta.build}.dedup.vcf.gz"
