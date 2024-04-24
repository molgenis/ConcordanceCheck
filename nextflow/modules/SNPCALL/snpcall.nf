process SNPCALL {
    tag "$pair_id"
    module = ['BCFtools/1.19-GCCcore-11.3.0','SAMtools/1.16.1-GCCcore-11.3.0']

    input:
    tuple val(meta), path(alignmentfile)

    output:
    tuple val(meta), path(vcf)

    shell:
    sampleId="${meta.dataId}"
    alignmentfile="${alignmentfile}"
    vcf="${meta.dataId}.called.sorted.vcf.gz"
    
    template 'snpcall.sh'

    stub:
    vcf="${meta.dataId}.called.sorted.vcf.gz"
    """
    touch "${vcf}"
    """
}
