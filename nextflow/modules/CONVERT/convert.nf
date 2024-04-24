process CONVERT {
    tag "$pair_id"
    module = ['array-as-vcf/1.1.0-GCCcore-11.3.0-Python-3.10.4','HTSlib/1.16-GCCcore-11.3.0']

    input:
    tuple val(meta), path(oafile)

    output:
    tuple val(meta), path(vcf)

    shell:
    sampleId="${meta.dataId}"
    oafile="${oafile}"
    vcf="${meta.dataId}.converted.vcf.gz"
    
    template 'convert.sh'

    stub:
    vcf="${meta.dataId}.converted.vcf.gz"
    """
    touch "${vcf}"
    """
}
