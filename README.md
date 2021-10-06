# ConcordanceCheck

Automation using Bash scripts and Cron jobs, inorder to automate the concordance check calculations. 


#### Code style

- Indentation: <TABS>
- environment variables: ALL\_UPPERCASE\_WITH\_UNDERSCORES
- global script variables: camelCase
- local function variables: _camelCasePrefixedWithUnderscore
- `if ... then`, `while ... do` and `for ... do` not on a single line, but on two lines with the `then` or `do` on the next line. E.g.
  ```
  if ...
  then
      ...
  elif ...
  then
      ...
  fi
  ```


## Version 1.x
See separate README_v1.md for details on the (deprecated) version
## Version 2.x

#### Repo layout
```

|-- bin/......................... Bash scripts for managing data staging, data analysis and monitoring / error handling.
|-- etc/......................... Config files in bash syntax. Config files are sourced by the scripts in bin/.
|   |-- <group>.cfg.............. Group specific variables.
|   |-- <site>.cfg............... Site / server specific variables.
|   `-- sharedConfig.cfg......... Generic variables, which are the same for all group and all sites / servers.
`-- lib/
    `-- sharedFunctions.bash..... Generic functions for error handling, logging, track & trace, etc.
```

#### Data flow

```
      ⎛¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯⎞       ⎛¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯⎞
      ⎜ LFS  ⎜ The NGS_DNA pipeline is finished  ⎜>> + >>⎜ LFS  ⎜ The GAP pipeline is finished         ⎜ 
      ⎝__________________________________________⎠       ⎝_____________________________________________⎠
                                                    v
                                                    v  
                                                    v
   ⎛¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯⎞
   ⎜ LFS dat0*  ⎜ jobfile is put on dat06 in the /groups/umcg-gd/dat06/ConcordanceCheckSamplesheet folder                   ⎜ 
   ⎝__________________________________________________________________________________________________________________⎠
                                                    v
                                                    v <<<< 1: ParseDarwinSamplesheet.sh
                                                    v
   ⎛¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯⎞
   ⎜ LFS prm0*  ⎜ Script is executed by ateambot user, creating a samplesheet on TMP on the diagnostic cluster              ⎜
   ⎝__________________________________________________________________________________________________________________⎠
                                                    v
                                                    v <<<< 2: ConcordanceCheck.sh 
                                                    v
   ⎛¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯⎞
   ⎜ LFS  ⎜ Copies the ngs VCF and the array VCF file to tmp*.                                       ⎜
   ⎜ tmp* ⎜ Calculates concordance between the ngs and the array VCF files.                          ⎜
   ⎝_________________________________________________________________________________________________⎠
                                                    v
                                                    v
   ⎛¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯¯⎞
   ⎜ LFS  ⎜ Concordance check output is copied to prm0*.                                      ⎜ LFS   ⎜
   ⎜ tmp* ⎜ A file containing the location of the Concordance check output is stored on dat0* ⎜ prm0* ⎜
   ⎜      ⎜                                                                                   ⎜ dat0* ⎜
   ⎝_________________________________________________________________________________________________⎠
     v                                                                                           ^
     v                                                                                           ^
      `>>>>>>>>>>>>>>>> 3: CopyConcordanceData.sh >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>^

```

```
flow chaperone (prm06) --> leucine-zipper (tmp06) --> chaperone (prm06)

#### chaperone
###### umcg-gd-ateambot 
module load ConcordanceCheck/${version} ; ParseDarwinSamplesheet.sh -g umcg-gd -a umcg-gap

#### leucine-zipper
###### umcg-gd-ateambot 
module load ConcordanceCheck/${version} ; ConcordanceCheck.sh -g umcg-gd

#### chaperone
##### umcg-gd-dm
module load ConcordanceCheck/${version} ; CopyConcordanceData.sh -g umcg-gd

```


#### Job control flow

The path to phase.state files must be:
```
${TMP_ROOT_DIR}/logs/${ConcordanceCheckID}.${phase}.${state}
```
Phase is in most cases the name of the executing script as determined by ```${SCRIPT_NAME}```.
State is either ```started```, ```failed``` or ```finished```.

```
## PROCESSING ##

ParseDarwinSamplesheet.sh -g NGSGROUP -a ARRAYGROUP => 


ConcordanceCheck.sh -g GROUP => ${cluster}:${TMP_ROOT_DIR}/logs/${project}/${run}.ConcordanceCheck.started
				${cluster}:${TMP_ROOT_DIR}/logs/${project}/${run}.ConcordanceCheck.finished

CopyConcordanceData.sh -g GROUP => ${cluster}:${PRM_ROOT_DIR}/concordance/logs/${ConcordanceCheckID}.CopyConcordanceCheckData.started
				${cluster}:${PRM_ROOT_DIR}/concordance/logs/${ConcordanceCheckID}.CopyConcordanceCheckData.finished

```
#### notifications.sh (Not (yet) for the concordancecheck, do we want this?)

To configure e-mail notification by the notifications script, 
edit the ```NOTIFY_FOR_PHASE_WITH_STATE``` array in ```etc/${group}.cfg``` 
and list the <phase>:<state> combinations for which email should be sent. E.g.:
```
declare -a NOTIFY_FOR_PHASE_WITH_STATE=(
	'copyRawDataToPrm:failed'
	'copyRawDataToPrm:finished'
	'pipeline:failed'
	'copyProjectDataToPrm:failed'
	'copyProjectDataToPrm:finished'
)
```
In addition there must be a list of e-mail addresses (one address per line) for each state for which email notifications are enabled in:
```
${TMP_ROOT_DIR}/logs/${phase}.mailinglist
```
In case the list of addresses is the same for mutiple states, you can use symlinks per state. E.g.
```
${TMP_ROOT_DIR}/logs/all.mailinglist
${TMP_ROOT_DIR}/logs/${phase1}.mailinglist -> ./all.mailinglist${TMP_ROOT_DIR}/logs/${phase2}.mailinglist -> ./all.mailinglist
```

#### cleanup.sh (Not (yet) for the concordancecheck, do we want this?)

The cleanup script runs once a day, it will clean up old data:
- Remove all the GavinStandAlone project/generatedscripts/tmp data once the GavinStandAlone has a ${project}.vcf.finished in ${TMP_ROOT_DIR}/GavinStandAlone/input
- Clean up all the raw data that is older than 30 days, it first checks if the data is copied to prm 
  - check in the logs if ${filePrefix}.copyRawDataToPrm.sh.finished 
  - count *.fq.gz on tmp and prm and compare for an extra check
- All the project + tmp data older than 30 days will also be deleted
  - when ${project}.projectDataCopiedToPrm.sh.finished

#### Who runs what and where

|Script                        |User              |Running on site/server     |
|------------------------------|------------------|---------------------------|
|1. ParseDarwinSamplesheet     |${group}-ateambot |HPC Cluster with tmp mount |
|2. ConcordanceCheck           |${group}-ateambot |HPC Cluster with tmp mount |
|3. copyConcordanceCheckData   |${group}-dm       |HPC Cluster with prm mount |
|4. notifications              |${group}-ateambot |HPC Cluster with tmp mount |
|5. cleanup                    |${group}-ateambot |HPC Cluster with tmp mount |


#### Location of job control and log files

 - LFS = logical file system; one of arc*, scr*, tmp* or prm*.
 - ConcordanceCheck has it's own dirs and does NOT touch/modify/create any data in the projects dir.

```
/groups/${group}/${LFS}/concordance
                 |-- samplesheets/
                 |   |-- ${ConcordanceCheckID}.sampleId.txt
                 |   |-- archive/
                 |-- logs/............................ Logs from ConcordanceCheck.
                 |       |-- ${ConcordanceCheckID}.${SCRIPT_NAME}.log
                 |       |-- ${ConcordanceCheckID}.${SCRIPT_NAME}.[started|failed|finished]
                 |       |-- ${ConcordanceCheckID}.${SCRIPT_NAME}.[started|failed|finished].mailed (not yet)
                 |-- jobs/
                 |-- array/
                 |   |-- ${arrayVcf}
                 |-- ngs/
                 |   |-- ${ngsVcf}
                 |-- results
                 |   |-- ${ConcordanceCheckID}.sample
                 |   |-- ${ConcordanceCheckID}.varinat
                 |-- heranalyse
                 |-- verificaties
                 |-- tmp


```

