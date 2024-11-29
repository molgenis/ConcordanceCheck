process FILTER {
    label 'filter'
    tag "$pair_id"
    module = ['BCFtools/1.19-GCCcore-11.3.0','SAMtools/1.16.1-GCCcore-11.3.0']

    input:
    tuple val(meta), path(file)

    output:
    tuple val(meta), path(vcf)

    shell:

    file="${file}"
    sampleId="${meta.dataId}"
    vcf="${meta.dataId}.${params.build}.DPfiltered.vcf.gz"

    template 'filter.sh'

    stub:

    vcf="${meta.dataId}.${params.build}.DPfiltered.vcf.gz"
 
    """
    touch "${vcf}"
    """
}
