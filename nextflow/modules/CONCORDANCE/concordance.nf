process CONCORDANCE {
    label 'concordance'
    tag "$pair_id"
    module = ['CompareGenotypeCalls/1.8.1-Java-8-LTS','HTSlib/1.16-GCCcore-11.3.0']

    publishDir "$params.output", mode: 'copy', overwrite: true

    input:
    tuple val(id), val(meta), val(files)

    output:
    tuple val(meta), path(sampleFile), path(variantFile)

    shell:

    vcf1 = "${files[0]}"
    vcf2 = "${files[1]}"
    sampleFile="${id}_${meta[0].dataId}_${meta[1].dataId}.sample"
    variantFile="${id}_${meta[0].dataId}_${meta[1].dataId}.variants"

    template 'concordance.sh'

    stub:

    sampleFile="${id}_${meta[0].dataId}_${meta[1].dataId}.sample"
    variantFile="${id}_${meta[0].dataId}_${meta[1].dataId}.variants"
    """
    touch "${sampleFile}"
    touch "${variantFile}"
    """
}
