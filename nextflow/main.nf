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
include { SNPCALL }  from './modules/SNPCALL/snpcall'
include { FILTER }  from './modules/FILTER/filter'
include { CONCORDANCE }  from './modules/CONCORDANCE/concordance'

def split_samples( row ) {
    def sampleList = []

    def sample1Metadata = [ "processStepId": row.processStepId,
    "dataId": row.data1Id,
    "build": row.build1,
    "project": row.project1,
    "fileType": row.fileType1,
    "fileprefix": row.fileprefix,
    "liftover": check_liftover(row.build1, row),
    "file": file(row.location1)]

    def sample2Metadata = [ "processStepId": row.processStepId,
    "dataId": row.data2Id,
    "build": row.build2,
    "project": row.project2,
    "fileType": row.fileType2,
    "fileprefix": row.fileprefix,
    "liftover": check_liftover(row.build2, row),
    "file": file(row.location2)]

    sampleList = [sample1Metadata,sample2Metadata]

    return sampleList
    }

def check_liftover( rowbuild, row ){
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

/**
 * return validated groupTuple result
 */
def validateGroup( key, group, files ) {
  // validate group size
  if(key.getGroupSize() != group.size() || key.getGroupSize() != files.size()) {
    throw new RuntimeException("error: expected group size '${key.getGroupSize()}' differs from actual group size '${group.size()}' or '${files.size()}'. this might indicate a bug in the software")
  }

  // extract key from 'nextflow.extension.GroupKey'
  def keyTarget = key.getGroupTarget()

  // workaround: groupTuple can return a group of type 'nextflow.util.ArrayBag' which does not implement hashCode/equals 
  def groupList = group.collect()
  def filesList = files.collect()

  return [keyTarget, groupList, filesList]
}

workflow {
    Channel.fromPath( params.samplesheet ) \
        | splitCsv( header:true, sep: '\t' )
        | map { split_samples(it) }
        | flatten
        | branch { sample ->
            OPENARRAY: sample.fileType.toUpperCase() ==~ /OPENARRAY/
            CRAMBAM: sample.fileType.toUpperCase() ==~ /CRAM/ || sample.fileType.toUpperCase() ==~ /BAM/
            VCF: sample.fileType.toUpperCase() ==~ /VCF/
            UNKNOWN: true 
            }
        | set { ch_sample }

    ch_sample.OPENARRAY
    | map { meta -> [ meta, meta.file ] }
    | CONVERT
    | map { meta, file -> [ meta, file ] }
    | branch { meta, file ->
        take: meta.liftover == true
        ready: true 
        }
    | set { ch_oa_liftover }

    ch_sample.CRAMBAM
    | map { meta -> [ meta, meta.file ]}
    | SNPCALL
    | branch { meta, file ->
        take: meta.liftover == true
        ready: true 
        }
    | set { ch_snpcall_liftover }

    ch_sample.VCF
    | map { meta -> [ meta, meta.file ]}
    | branch { meta, file ->
        take: meta.liftover == true
        ready: true 
            }
    | set { ch_vcf_liftover }

    Channel.empty().mix( ch_vcf_liftover.take, ch_oa_liftover.take, ch_snpcall_liftover.take )
    | LIFTOVER
    | set { ch_vcfs_liftovered }

    ch_sample.UNKNOWN
    | subscribe { item -> println "Error, got UNKNOWN fileType: ${item}" }

    Channel.empty().mix( ch_vcfs_liftovered, ch_vcf_liftover.ready, ch_oa_liftover.ready, ch_snpcall_liftover.ready)
    | FILTER
    | map { sample , file -> [groupKey(sample.processStepId, 2), sample, file ] }
    | groupTuple( remainder: true )
    | map { key, group, files -> validateGroup(key, group, files) }
    | set { ch_vcfs_concordance }

    ch_vcfs_concordance
    | map { meta -> [ meta[0], meta[1], meta[2] ] }
    | view
    | CONCORDANCE
}
