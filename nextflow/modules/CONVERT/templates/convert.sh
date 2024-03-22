#!/bin/bash

set -o pipefail
set -eu

    if [[ "!{meta.fileType1}" == "OPENARRAY" ]]
    then
        oafile="!{files[0]}"
        sampleId="!{meta.data1Id}"
        if [[ "!{files[1]}" == *".gz" ]]
        then
            cp "!{files[1]}" "!{vcf2}"
        else
            bgzip -c "!{files[1]}" > "!{vcf2}"
        fi
    else
        oafile="!{files[1]}"
        sampleId="!{meta.data2Id}"
        if [[ "!{files[0]}" == *".gz" ]]
        then
            cp "!{files[0]}" "!{vcf1}"
        else
            bgzip -c "!{files[0]}" > "!{vcf1}"
        fi
    fi

    # Convert openarray file to vcf.
    array-as-vcf --sample-name "${sampleId}" --path "${oafile}" --build GRCh37 > "${sampleId}.converted.vcf"
    bgzip -c "${sampleId}.converted.vcf" > "${sampleId}.converted.vcf.gz"
