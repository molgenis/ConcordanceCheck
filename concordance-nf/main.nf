#!/usr/bin/env nextflow

nextflow.enable.dsl=2

log.info """\
         CONCORDANCE-NF   P I P E L I N E
         ===================================
         outputDir    : ${params.outputDir}
         samplesheet  : ${params.samplesheet}
         launchDir    : ${params.launchDir}
         mappingFile  : ${params.mappingFile}
         """
         .stripIndent()

include { LIFTOVER } from './modules/LIFTOVER/liftover'
include { CONVERT }  from './modules/CONVERT/convert'
include { CHECK }  from './modules/CHECK/check'
include { CONCORDANCE }  from './modules/CONCORDANCE/concordance'

workflow {
    Channel.fromPath(params.samplesheet) \
        | splitCsv(header:true, sep: '\t') \
        | map { row -> [[ 
                    data1Id:row.data1Id,
                    data2Id:row.data2Id, 
                    build1:row.build1, 
                    build2:row.build2, 
                    fileType1:row.fileType1, 
                    fileType2:row.fileType2 ],
                    [file(row.location1), file(row.location2)]] } \
        // convert if fileType is not VCF.
        | view
        | branch { meta, files ->
            take: meta.fileType1 ==~ /OPENARRAY/ || meta.fileType2 ==~ /OPENARRAY/
            ready: true }
        | set { ch_sample }

    ch_sample.take
    | CONVERT
    | map { meta, file1,file2 -> [meta,[ file1, file2 ] ]}
    | set { ch_samples_processed }

    Channel.empty().mix(ch_samples_processed, ch_sample.ready)
    | branch { meta, files ->
        take: meta.build1 != meta.build2
        ready: true }
    | set { ch_sample_liftover }

    ch_sample_liftover.take
    | LIFTOVER
    | map { meta, file1, file2 -> [meta,[ file1, file2 ] ]}
    | set { ch_sample_liftovered }

    Channel.empty().mix( ch_sample_liftovered, ch_sample_liftover.ready )
    | view
//    | branch { meta, files ->
  //      ready: files[0] =~ /.gz/ && files[1] =~ /.gz/
  //      take: true }
    | set { ch_sample_check }
    
//    ch_sample_check.take
    ch_sample_check
    | view
    | CHECK
    | map { meta, file1,file2 -> [meta,[ file1, file2 ] ]}
    | set { ch_sample_checked }

//    Channel.empty().mix( ch_sample_checked, ch_sample_check.ready )
    Channel.empty().mix( ch_sample_checked )
    | view
    | CONCORDANCE
}
