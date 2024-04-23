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
        tuple val(id), val(meta), val(files) 

    """
    echo "Id ${id} , meta: ${meta[0].dataId} en ${meta[1].dataId}, files: ${files[0]} en ${files[1]} "

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
    | branch { meta, file ->
        take: meta.liftover == true
        ready: true 
            }
    | set { ch_vcf_liftover }

    Channel.empty().mix( ch_vcf_liftover.take, ch_oa_liftover.take )
 //   | view
    | LIFTOVER
    | set { ch_vcfs_liftovered }

    ch_sample.UNKNOWN
    | view
    | set { my_channel }
    //| EXIT2

    Channel.empty().mix( ch_vcfs_liftovered, ch_vcf_liftover.ready, ch_oa_liftover.ready)
//    | view
    | map { sample , file -> [groupKey(sample.processStepId, 2), sample, file ] }
    | groupTuple( remainder: true )
//    | !!fix
//    | map { key, group, files -> [ validateGroup(key, group), files ] }
    | view
    | set { my_channel }


    my_channel
    | map {meta -> [ meta[0], meta[1], meta[2] ] }
 //   | tupleExample
    | CONCORDANCE

}
