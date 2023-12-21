process CONCORDANCE {
    label 'concordance'
    tag "$pair_id"
    module = ['CompareGenotypeCalls/1.8.1-Java-8-LTS','HTSlib/1.16-GCCcore-11.3.0']

    publishDir "$params.output/concordance/results", mode: 'copy', overwrite: true

    input:
    tuple val(meta), path(files)

    output:
    tuple val(meta), path(sampleFile), path(variantFile)

    shell:

    vcf1 = "${files[0]}"
    vcf2 = "${files[1]}"
    sampleFile="${meta.data1Id}_${meta.data2Id}.sample"
    variantFile="${meta.data1Id}_${meta.data2Id}.variants"

    template 'concordance.sh'

    stub:

    sampleFile="${meta.data1Id}_${meta.data2Id}.sample"
    variantFile="${meta.data1Id}_${meta.data2Id}.variant"
    """
    touch "${sampleFile}"
    touch "${variantFile}"
    """
}