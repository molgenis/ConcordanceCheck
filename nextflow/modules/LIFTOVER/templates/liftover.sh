#!/bin/bash

set -o pipefail
set -eu

    sampleId="!{meta.dataId}"

    java -Djava.io.tmpdir="!{params.tmpDir}" \
    -XX:ParallelGCThreads="!{task.cpus}" \
    "-Xmx!{task.memory.toMega() - 256}m" \
    -jar "${EBROOTPICARD}/picard.jar" \
    LiftoverVcf \
    --CHAIN "!{params.chain}" \
    --INPUT "!{file}" \
    --OUTPUT "!{sampleId}.!{params.build}.vcf" \
    --REFERENCE_SEQUENCE "!{params.reference.b38}" \
    --REJECT "${sampleId}.!{params.build}.rejected.vcf" \
    --MAX_RECORDS_IN_RAM 100000 \
    --TMP_DIR "!{params.tmpDir}" \
    --VERBOSITY WARNING \
    --WARN_ON_MISSING_CONTIG true \
    --WRITE_ORIGINAL_ALLELES true \
    --WRITE_ORIGINAL_POSITION true

    bgzip -c "!{sampleId}.!{params.build}.vcf" > "!{sampleId}.!{params.build}.vcf.gz"
    bgzip -c "!{sampleId}.!{params.build}.rejected.vcf" > "!{sampleId}.!{params.build}.rejected.vcf.gz"  
