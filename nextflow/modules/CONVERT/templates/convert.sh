#!/bin/bash

set -o pipefail
set -eu

    # Convert openarray file to vcf.
    array-as-vcf \
    --sample-name "!{sampleId}" \
    --path "!{oafile}" \
    --build GRCh37 \
    --lookup-table "!{params.lookupTable.b37}" \
    --log-level DEBUG \
    --no-ensembl-lookup > "!{sampleId}.converted.vcf"

    bgzip -c "!{sampleId}.converted.vcf" > "!{sampleId}.converted.vcf.gz"
