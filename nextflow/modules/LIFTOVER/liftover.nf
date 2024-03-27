process LIFTOVER {
    label 'liftover'
    tag "$pair_id"
    module = ['picard/2.26.10-Java-8-LTS','HTSlib/1.16-GCCcore-11.3.0']

    input:
    tuple val(meta), path(files)

    output:
    tuple val(meta), path(vcf1), path(vcf2)

    shell:

    vcf1 = "${meta.data1Id}.${params.build}.vcf.gz"
    vcf2 = "${meta.data2Id}.${params.build}.vcf.gz"

    meta["build1"] = "${params.build}"
    meta["build2"] = "${params.build}"

    template 'liftover.sh'

    stub:

    vcf1="${meta.data1Id}.${params.build}.vcf.gz"
    vcf2="${meta.data2Id}.${params.build}.vcf.gz"

    meta["build2"] = "${params.build}"
    meta["build1"] = "${params.build}"
 
    """
    touch "${vcf1}"
    touch "${vcf2}"
    """
}
