process LIFTOVER {
    label 'liftover'
    tag "$pair_id"
    module = ['picard/2.26.10-Java-8-LTS','HTSlib/1.16-GCCcore-11.3.0']

    input:
    tuple val(meta), path(file)

    output:
    tuple val(meta), path(vcf)

    shell:

    file="${file}"
    sampleId="${meta.dataId}"
    vcf="${meta.dataId}.${params.build}.vcf.gz"

    template 'liftover.sh'

    stub:

    vcf="${meta.dataId}.${params.build}.vcf.gz"
 
    """
    touch "${vcf}"

    """
}
