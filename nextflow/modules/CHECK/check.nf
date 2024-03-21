process CHECK {
    label 'check'
    tag "$pair_id"
    module = ['HTSlib/1.16-GCCcore-11.3.0']

    input:
    tuple val(meta), path(files)

    output:
    tuple val(meta), path(vcf1), path(vcf2)

    script:
    vcf1="${meta.data1Id}.${meta.build1}.final.vcf.gz"
    vcf2="${meta.data2Id}.${meta.build2}.final.vcf.gz"
    """
    if [[ "${files[0]}"  != *".gz" ]]; then
        bgzip -c "${files[0]}" > "${files[0]}.gz"
        mv "${files[0]}.gz" "${vcf1}"
        #files[0]="${files[0]}.gz"
    else
        mv "${files[0]}" "${vcf1}" 2>/dev/null; true
    fi 
    if [[ "${files[1]}" != *".gz" ]]; then
        bgzip -c "${files[1]}" > "${files[1]}.gz"
        mv "${files[1]}.gz" "${vcf2}"
        #files[1]="${files[1]}.gz"
    else
        mv "${files[1]}" "${vcf2}" 2>/dev/null; true
    fi
    """
    stub:

    vcf1="${meta.data1Id}."${meta.build1}.vcf.gz
    vcf2="${meta.data2Id}."${meta.build2}.vcf.gz
    """
    touch "${vcf1}"
    touch "${vcf2}"
    """
}
