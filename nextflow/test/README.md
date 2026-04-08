# Tests for ConcordanceCheck

# samples
# NA24385 VCF:      DNA-001 t/m DNA-006, RNA-008 / RNA-009
#         BAM/CRAM: NA24385

# NA12878 VCF:      DNA-001 
#         BAM/CRAM: RNA-008, DNA-004.GRCh37 DNA-001.GRCh37
#         OPAR:     OA001, OA002

# Testcases: 

## DNA → RNA
| TEST ID| InputType A | Sample A       | InputType B | Sample B       | Datatypes | Build mix | Testtype                   |
| ------ | ----------- | -------------- | ----------- | -------------- | --------- | --------- | -------------------------- |
| 100000 | vcf         | DNA-001.GRCh37 | vcf         | RNA-008.GRCh37 | DNA → RNA | same (37) | same-build/cross-platform  |
| 100001 | vcf         | DNA-001.GRCh38 | vcf         | RNA-008.GRCh37 | DNA → RNA | 38 vs 37  | cross-build/cross-platform |
| 100002 | vcf         | DNA-002.GRCh37 | vcf         | RNA-009.GRCh38 | DNA → RNA | 37 vs 38  | cross-build/cross-platform |
| 100003 | vcf         | DNA-002.GRCh38 | vcf         | RNA-009.GRCh38 | DNA → RNA | same (38) | same-build/cross-platform  |
| 100014 | vcf         | DNA-001.GRCh37 | bam         | RNA-008.GRCh37 | DNA → RNA | same (37) | same-build/cross-platform  swap |
| 100015 | vcf         | DNA-001.GRCh38 | cram        | RNA-008.GRCh37 | DNA → RNA | 38 vs 37  | cross-build/cross-platform swap |
| 100016 | vcf         | DNA-002.GRCh37 | bam         | RNA-009.GRCh38 | DNA → RNA | 37 vs 38  | todo.                      |
| 100017 | vcf         | DNA-002.GRCh38 | cram        | RNA-009.GRCh38 | DNA → RNA | same (38) | todo.                      |
|        | vcf         | NA12878.GRCh37 | bam         | RNA-008.GRCh37 | DNA → RNA | same (37) | todo. same-build/cross-platform  | x
|        | vcf         | NA12878.GRCh37 | cram        | RNA-008.GRCh37 | DNA → RNA | same (37) | todo. same-build/cross-platform  | x
|        | bam         | NA12878.GRCh37 | bam         | RNA-008.GRCh37 | DNA → RNA | same (37) | todo. same-build/cross-platform  | x
|        | cram        | NA12878.GRCh37 | cram        | RNA-008.GRCh37 | DNA → RNA | same (37) | todo. same-build/cross-platform  | x
|        | cram        | NA12878.GRCh37 | bam         | RNA-008.GRCh37 | DNA → RNA | same (37) | todo. same-build/cross-platform  | x
|        | bam         | NA12878.GRCh37 | cram        | RNA-008.GRCh37 | DNA → RNA | same (37) | todo. same-build/cross-platform  | x
|        | vcf         | NA12878.GRCh38 | bam         | RNA-008.GRCh37 | DNA → RNA | 38 vs 37  | todo. same-build/cross-platform  | x
|        | vcf         | NA12878.GRCh38 | cram        | RNA-008.GRCh37 | DNA → RNA | 38 vs 37  | todo. same-build/cross-platform  | x
|        | bam         | NA12878.GRCh38 | bam         | RNA-008.GRCh37 | DNA → RNA | 38 vs 37  | todo. same-build/cross-platform  | x
|        | cram        | NA12878.GRCh38 | cram        | RNA-008.GRCh37 | DNA → RNA | 38 vs 37  | todo. same-build/cross-platform  | x
|        | cram        | NA12878.GRCh38 | bam         | RNA-008.GRCh37 | DNA → RNA | 38 vs 37  | todo. same-build/cross-platform  | x
|        | bam         | NA12878.GRCh38 | cram        | RNA-008.GRCh37 | DNA → RNA | 38 vs 37  | todo. same-build/cross-platform  | x

##  DNA → DNA
| TEST ID| InputType A | Sample A       | InputType B | Sample B           | Datatypes | Build mix | Testtype                  |
| ------ | ----------- | -------------- | ----------- | ------------------ | --------- | --------- | ------------------------- |
| 100004 | vcf         | DNA-003.GRCh37 | vcf         | DNA-004.GRCh37     | DNA → DNA | same (37) | same-build/same-platform  |
| 100005 | vcf         | DNA-003.GRCh37 | vcf         | DNA-005.GRCh38     | DNA → DNA | 37 vs 38  | cross-build/same-platform |
| 100006 | vcf         | DNA-004.GRCh38 | vcf         | DNA-005.GRCh37     | DNA → DNA | 38 vs 37  | cross-build/same-platform |
| 100007 | vcf         | DNA-004.GRCh38 | vcf         | DNA-003.GRCh38     | DNA → DNA | same (38) | same-build/same-platform  |
| 100018 | vcf         | DNA-003.GRCh37 | bam         | DNA-004.GRCh37     | DNA → DNA | same (37) | same-build/same-platform swap |
| 100019 | vcf         | DNA-003.GRCh37 | cram        | NA24385.GRCh38     | DNA → DNA | 37 vs 38  | cross-build/same-platform |
| 100020 | vcf         | DNA-004.GRCh38 | bam         | DNA-001.GRCh37     | DNA → DNA | 38 vs 37  | cross-build/same-platform swap|
| 100021 | vcf         | DNA-004.GRCh38 | cram        | NA24385.GRCh38     | DNA → DNA | same (38) | same-build/same-platform  |
| 100028 | bam         | NA12878.GRCh37 | vcf         | DNA-005.GRCh37     | DNA → DNA | same (37) | same-build/same-platform swap |
| 100029 | bam         | NA12878.Hs38d1 | vcf         | DNA-001.GRCh37     | DNA → DNA | 38 vs 37  | todo: buildminmatch chr.  |
| 100030 | bam         | NA12878.GRCh38 | vcf         | DNA-005.GRCh37     | DNA → DNA | 38 vs 37  | cross-build/same-platform swap |
| 100031 | cram        | NA12878.GRCh38 | vcf         | DNA-005.GRCh37     | DNA → DNA | 38 vs 37  | cross-build/same-platform swap |
| 100032 | cram        | NA12878.GRCh37 | vcf         | NA12878.GRCh37     | DNA → DNA | same (37) | same-build/same-platform  | 
| 100039 | cram        | NA12878.GRCh37 | vcf         | NA12878.GRCh37     | DNA → DNA | same (37) | todo: bug: name conflixt  |
| 100040 | cram        | NA12878.GRCh37 | vcf         | NA12878.GRCh37     | DNA → DNA | same (37) | todo: bug: vcf id not updated  |

## RNA -> RNA
| TEST ID| InputType A | Sample A       | InputType B | Sample B       | Datatypes | Build mix | Testtype                  |
| ------ | ----------- | -------------- | ----------- | -------------- | --------- | --------- | ------------------------- |
| 100008 | vcf         | RNA-009.GRCh37 | vcf         | RNA-008.GRCh37 | RNA → RNA | same (37) | same-build/same-platform  |
| 100009 | vcf         | RNA-009.GRCh37 | vcf         | RNA-008.GRCh38 | RNA → RNA | 37 vs 38  | cross-build/same-platform |
| 100010 | vcf         | RNA-008.GRCh38 | vcf         | RNA-009.GRCh37 | RNA → RNA | 38 vs 37  | cross-build/same-platform |
| 100011 | vcf         | RNA-008.GRCh38 | vcf         | RNA-009.GRCh38 | RNA → RNA | same (38) | same-build/same-platform  |
| 100022 | vcf         | RNA-008.GRCh37 | bam         | RNA-008.GRCh37 | RNA → RNA | same (37) | same-build/same-platform  swap |
| 100023 | vcf         | RNA-008.GRCh37 | cram        | RNA-009.GRCh38 | RNA → RNA | 37 vs 38  | todo.                     |
| 100024 | vcf         | RNA-009.GRCh38 | bam         | RNA-008.GRCh37 | RNA → RNA | 38 vs 37  | cross-build/same-platform swap |
| 100025 | vcf         | RNA-009.GRCh38 | cram        | RNA-008.GRCh38 | RNA → RNA | same (38) | todo.                     |

## DNA → OPAR
| TEST ID| InputType A | Sample A       | InputType B | Sample B        | Datatypes  | Build mix | Testtype                   |
| ------ | ----------- | -------------- | ----------- | --------------- | ---------- | --------- | -------------------------- |
| 100012 | vcf         | DNA-005.GRCh37 | txt         | OPAR-001.GRCh37 | DNA → OPAR | same (37) | same-build/cross-platform  swap |
| 100013 | vcf         | DNA-005.GRCh38 | txt         | OPAR-002.GRCh37 | DNA → OPAR | 38 vs 37  | cross-build/cross-platform swap |
| 100033 | vcf         | NA12878.GRCh38 | txt         | OPAR-001.GRCh37 | DNA → OPAR | 38 vs 37  | cross-build/cross-platform |
| 100034 | vcf         | NA12878.GRCh37 | txt         | OPAR-001.GRCh37 | DNA → OPAR | same (37) | cross-build/cross-platform |
| 100026 | bam         | DNA-004.GRCh37 | txt         | OPAR-001.GRCh37 | DNA → OPAR | same (37) | same-build/cross-platform low threshold |
| 100035 | bam         | NA12878.GRCh37 | txt         | OPAR-001.GRCh37 | DNA → OPAR | same (37) | same-build/cross-platform  |
| 100036 | bam         | NA12878.GRCh38 | txt         | OPAR-001.GRCh37 | DNA → OPAR | 38 vs 37  | same-build/cross-platform  |
| 100027 | cram        | NA12878.GRCh38 | txt         | OPAR-002.GRCh37 | DNA → OPAR | 38 vs 37  | cross-build/cross-platform |
| 100037 | cram        | NA12878.GRCh37 | txt         | OPAR-002.GRCh37 | DNA → OPAR | same (37) | cross-build/cross-platform |
| 100038 | cram        | NA12878.GRCh38 | txt         | OPAR-001.GRCh37 | DNA → OPAR | 38 vs 37  | cross-build/cross-platform |

## PGX → OPAR
| TEST ID| InputType A | Sample A       | InputType B | Sample B        | Datatypes  | Build mix | Testtype        |
| ------ | ----------- | -------------- | ----------- | --------------- | ---------- | --------- | --------------- |
|        | vcf         | NA12878.GRCh37 | txt         | OPAR-001.GRCh37 | PGX → OPAR | 37 vs 37  | cross-build/cross-platform |

## ONT → OPAR
| TEST ID| InputType A | Sample A       | InputType B | Sample B        | Datatypes  | Build mix | Testtype        |
| ------ | ----------- | -------------- | ----------- | --------------- | ---------- | --------- | --------------- |
|        | vcf         | NA12878.GRCh38 | txt         | OPAR-001.GRCh37 | ONT → OPAR | 38 vs 37  | cross-build/cross-platform |
|        | cram        | NA12878.GRCh38 | txt         | OPAR-002.GRCh37 | ONT → OPAR | 38 vs 37  | cross-build/cross-platform |