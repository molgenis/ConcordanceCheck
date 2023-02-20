#!/bin/bash
set -eu

concordanceDir="/groups/umcg-atd/tmp06/concordance/array-array/"
SAMPLE_ID="pathToSample"
#
##
### Needs an index folder with a file to compare with
### Data to compare with should be in ${concordanceDir}
### Creates subfolders automatically
### data will be bgzipped/tabix'ed
### only first 100K lines will be selected for comparison
### output will be in results ${concordanceDir}/results/
##
#

echo "creating workfolders : results,tmp,samplesheets,jobs and original in ${concordanceDir}"
mkdir -p "${concordanceDir}/"{results,tmp,samplesheets,jobs,original}

module load HTSlib
module list
## indexVCF to compare all input files with:
indexVcf="${concordanceDir}/index/${SAMPLE_ID}"

## grep first 100K lines for comparison
head -100000 "${indexVcf}" > "${indexVcf}.header100000"

# get sampleID out of filename
cp "${indexVcf}" "${concordanceDir}/original/"
indexBase=$(basename "${indexVcf%%.*}")
index="${indexBase}"

#CompareGenotypes needs a bgzipped file
bgzip -c "${indexVcf}.header100000" > "${indexVcf}.gz"
tabix -p vcf "${indexVcf}.gz"

for i in "${concordanceDir}"*".vcf"
do
	# get sampleID without path
	sampleIDBase=$(basename "${i}")
	# get sampleID without extension
	sampleID="${sampleIDBase%%.*}"

	#outputFile prefix
	concordanceCheckId="${index}_${sampleID}"

	#create sampleSheet for CompareGenotypes script
	sampleSheet="${concordanceDir}//samplesheets/${index}_${sampleID}.sampleId.txt"
	echo -e "data1Id\tdata2Id\tlocation1\tlocation2" > "${sampleSheet}"
	echo -e "${index}\t${sampleID}\t${indexVcf}\t${i}" >> "${sampleSheet}"

	## grep first 100K lines for comparison
	head -100000 "${i}" > "${i}.header100000"

	#CompareGenotypes needs a bgzipped file
	echo "tabixing ${i}"
	bgzip -c "${i}.header100000" > "${i}.gz"
	tabix -p vcf  "${i}.gz"


# create jobs (EOH must stay left aligned, NO INDENTATION!

cat << EOH > "${concordanceDir}/jobs/${concordanceCheckId}.sh"
#!/bin/bash
#SBATCH --job-name=Concordance_${concordanceCheckId}
#SBATCH --output=${concordanceDir}/jobs/${concordanceCheckId}.out
#SBATCH --error=${concordanceDir}/jobs/${concordanceCheckId}.err
#SBATCH --time=00:30:00
#SBATCH --cpus-per-task 1
#SBATCH --mem 6gb
#SBATCH --open-mode=append
#SBATCH --export=NONE
#SBATCH --get-user-env=60L

set -eu
	module load CompareGenotypeCalls
	module load BEDTools
	module list
	java -XX:ParallelGCThreads=1 -Djava.io.tmpdir="${concordanceDir}/temp/" -Xmx9g -jar \${EBROOTCOMPAREGENOTYPECALLS}/CompareGenotypeCalls.jar \
	-d1 "${indexVcf}.gz" \
	-D1 VCF \
	-d2 "${i}.gz" \
	-D2 VCF \
	-ac \
	--sampleMap "${sampleSheet}" \
	-o "${concordanceDir}/tmp/${concordanceCheckId}" \
	-sva

	echo "moving ${concordanceDir}/tmp/${concordanceCheckId}.sample to ${concordanceDir}/results/"
	mv "${concordanceDir}/tmp/${concordanceCheckId}.sample" "${concordanceDir}/results/"
	echo "moving ${concordanceDir}/tmp/${concordanceCheckId}.variants to ${concordanceDir}/results/"
	mv "${concordanceDir}/tmp/${concordanceCheckId}.variants" "${concordanceDir}/results/"

	echo "finished"
	if [ -e "${concordanceDir}/logs/${concordanceCheckId}.ConcordanceCheck.started" ]
	then
		mv "${concordanceDir}/logs/${concordanceCheckId}.ConcordanceCheck."{started,finished}
	else
		touch "${concordanceDir}/logs/${concordanceCheckId}.ConcordanceCheck.finished"
	fi

	mv "${concordanceDir}/jobs/${concordanceCheckId}.sh."{started,finished}
EOH

echo "submitting: ${concordanceDir}/jobs/${concordanceCheckId}.sh"
sbatch "${concordanceDir}/jobs/${concordanceCheckId}.sh"

done


