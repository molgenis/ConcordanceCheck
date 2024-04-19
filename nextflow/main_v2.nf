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

//include { LIFTOVER } from './modules/LIFTOVER/liftover'
//include { CONVERT }  from './modules/CONVERT/convert'
//include { CHECK }  from './modules/CHECK/check'
//include { CONCORDANCE }  from './modules/CONCORDANCE/concordance'

include { LIFTOVER } from './modules/LIFTOVER_v2/liftover'
include { CONVERT }  from './modules/CONVERT_v2/convert'
include { CHECK }  from './modules/CHECK_v2/check'
include { CONCORDANCE }  from './modules/CONCORDANCE_v2/concordance'

def split_samples(row) {
    def sampleList = []

    def sample1Metadata = [ "processStepId": row.processStepId,
    "dataId": row.data1Id,
    "build": row.build1,
    "fileType": row.fileType1,
    "liftover": check_liftover(row.build1, row),
    "file": file(row.location1)]
    
    def sample2Metadata = [ "processStepId": row.processStepId,
    "dataId": row.data2Id,
    "build": row.build2,
    "fileType": row.fileType2,
    "liftover": check_liftover(row.build2, row),
    "file": file(row.location2)]

    sampleList = [sample1Metadata,sample2Metadata]

    return sampleList
    }

//def EXIT2 (item) {
//   throw new RuntimeException("Error: Unknown fileType :'${item}', check jobfile for listed filetypes.")
//   exit 1
//}

def check_liftover(rowbuild, row){
    if ( row.build1 != row.build2 && rowbuild != params.build ){
        return true
        }
    else if ( row.build1 != row.build2 && rowbuild == params.build ){
        return false
    }
    else if ( row.build1 == row.build2 ){
        return false
    }
    else {
        throw new RuntimeException("error: Something when wrong determenting liftover for:'${row.build1}' and '${row.build2}'")
    }

}

process tupleExample {
    input:
        tuple val(meta), val(data)

    """
    echo "Processing ${meta} , filelist1: ${data}"

      """
}
// echo "Processing ${meta} , filelist1: ${data[0]}, filelist2: ${data[1]}, liftover: ${data[0].liftover} ${data[1].liftover} "



/**
 * return validated groupTuple result
 */
def validateGroup(key, group) {
  // validate group size
  if(key.getGroupSize() != group.size()) {
    throw new RuntimeException("error: expected group size '${key.getGroupSize()}' differs from actual group size '${group.size()}'. this might indicate a bug in the software")
  }

  // extract key from 'nextflow.extension.GroupKey'
  def keyTarget = key.getGroupTarget()

  // workaround: groupTuple can return a group of type 'nextflow.util.ArrayBag' which does not implement hashCode/equals 
  def groupList = group.collect()
  
  return [keyTarget, groupList]
}

workflow {
    Channel.fromPath(params.samplesheet) \
        | splitCsv(header:true, sep: '\t')
        | map { split_samples(it) }
        | flatten
 //       | view
        | branch { sample ->
            OPENARRAY: sample.fileType ==~ /OPENARRAY/
            CRAMBAM: sample.fileType ==~ /CRAM/ || sample.fileType ==~ /BAM/
            VCF: sample.fileType ==~ /VCF/
            UNKNOWN: true 
             }
        | set { ch_sample }

    ch_sample.OPENARRAY
//    | view
    | map { meta -> [ meta, meta.file ] }
    | CONVERT
 //   | view
    | map { meta, file -> [ meta, file ] }
 //   | view
//    | flatten
    | branch { meta, file ->
        take: meta.liftover == true
        ready: true 
        }
    | set { ch_oa_liftover }

    ch_sample.CRAMBAM
    | view
    
    ch_sample.VCF
  //  | view
    | map {meta -> [ meta, meta.file ]}
   // | view
    //| flatten
    | branch { meta, file ->
        take: meta.liftover == true
        ready: true 
            }
    | set { ch_vcf_liftover }

    Channel.empty().mix( ch_vcf_liftover.take, ch_oa_liftover.take )
 //   | view
    | LIFTOVER
 //   | view
    | set { ch_vcfs_liftovered }

    ch_sample.UNKNOWN
    | view
    | set { my_channel }
    //| EXIT2

    Channel.empty().mix( ch_vcfs_liftovered, ch_vcf_liftover.ready, ch_oa_liftover.ready)
//    | view
    | map { sample , file -> [groupKey(sample.processStepId, 2), sample, file ] }
    | groupTuple( remainder: true )
    | view
    | map { key, group, file -> validateGroup(key, group) }
    | set { my_channel }


    my_channel
    | view
//    | map {key, group -> [ group ] }
    | tupleExample
//    | map {key, group -> [ group ] }
 //   | view

}
//break

/*
workflow {
    Channel.fromPath(params.samplesheet) \
        | splitCsv(header:true, sep: '\t') \
        | map { row -> [[ 
                    data1Id:row.data1Id,
                    data2Id:row.data2Id, 
                    build1:row.build1, 
                    build2:row.build2, 
                    fileType1:row.fileType1, 
                    fileType2:row.fileType2,
                    processStepId:row.processStepId ],
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
    | view
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
}*/
