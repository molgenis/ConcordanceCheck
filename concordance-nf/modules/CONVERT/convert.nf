process CONVERT {
    tag "$pair_id"
    module = ['array-as-vcf/1.1.0-GCCcore-11.3.0-Python-3.10.4','HTSlib/1.16-GCCcore-11.3.0']

    input:
    tuple val(meta), path(files)

    output:
    tuple val(meta), path(vcf1), path(vcf2)
    //tuple val(meta), path(vcf1), path(vcf2)
    //tuple val(meta), path('*.vcf*', arity: '2')

    shell:
    vcf1="${meta.data1Id}.converted.vcf.gz"
    vcf2="${meta.data2Id}.converted.vcf.gz"

    template 'convert.sh'

    stub:
    vcf1="${meta.data1Id}.converted.vcf.gz"
    vcf2="${meta.data2Id}.converted.vcf.gz"
    """
    touch "${vcf1}"
    touch "${vcf2}"
    """
}
