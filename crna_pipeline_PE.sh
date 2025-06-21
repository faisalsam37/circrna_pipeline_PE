

# Reference Files
DIR="/Users/faisalnihad/Documents/circRNA_project"
genome="$DIR/ref/Homo_sapiens.GRCh38.dna.primary_assembly.fa"
gtf="$DIR/ref/Homo_sapiens.GRCh38.111.gtf"

# Indexes
bwaindex="$DIR/index/bwa/grch38_primary"
hisat2index="$DIR/index/hisat/grch38/genome"
starindex="$DIR/index/star/grch38_v111"

# Trimmomatic
Trimmomatic="$DIR/Trimmomatic-0.39/Trimmomatic-0.39/trimmomatic-0.39.jar"
adapters="$DIR/adapters/TruSeq3-PE.fa"

# circRNA tools directories
ciri="$DIR/CIRI_v2.0.6/CIRI2.pl"
cfinder="$DIR/circRNA_finder-master/postProcessStarAlignment.pl" 
csplice="$DIR/CircSplice-master/CircSplice.pl"
cspliceFlat="$DIR/CircSplice-master/bed-refFlat_hg38.txt"


mkdir -p "$DIR/TrimmedPE" "$DIR/AlignedBWA" "$DIR/AlignedSTAR" "$DIR/QC" "$DIR/crnaRes"


# Untrimmed FASTQ
Folders=( * )
sF=${Folders[$SGE_TASK_ID]}
R1=$sF/*_1.fq.gz
R2=$sF/*_2.fq.gz

# Hold for each data
if ! [ -d $DIR/TrimmedPE/$sF ]; then
    mkdir $DIR/TrimmedPE/$sF
fi

# Trimmed FASTQ
out1=$DIR/TrimmedPE/$sF/$(basename $R1)
out2=$DIR/TrimmedPE/$sF/$(basename $R2)
out1u=$DIR/TrimmedPE/$sF/$(basename $R1).unpaired
out2u=$DIR/TrimmedPE/$sF/$(basename $R2).unpaired


# Debug
echo $sF
echo $R1
echo $out1
echo $out1u

# Load tools
module load samtools/1.19.2-gcc-12.2.0
module load openjdk/21.0.0_35-gcc-12.2.0
module load python/3.8.5-gcc-12.2.0
module load bwa/0.7.17-gcc-12.2.0
module load perl/5.38.0-gcc-12.2.0
module load star/2.7.1lb

# Trim
time java -jar $Trimmomatic PE -threads 24 $R1 $R2 $out1 $out1u $out2 $out2u ILLUMINACLIP:$adapters:2:30:10 SLIDINGWINDOW:4:20

# BWA output
BoutBam=$DIR/AlignedBWA/$(basename $out1).sam

# Debug
echo $BoutBam

# BWA 
time bwa mem -T 19 $bwaindex $out1 $out2 > $BoutBam

# ciri output
mkdir -p $DIR/crnaRes/ciri2
baseName=$(basename "$out1" | sed 's/_1.*//')
ciriouttxt=$DIR/crnaRes/ciri2/${baseName}_ciri2.txt
cirioutlog=$DIR/crnaRes/ciri2/${baseName}_ciri2.log


# ciri
perl $ciri -I $BoutBam -O $ciriouttxt -F $genome -A $gtf -G $cirioutlog

# STAR output
SoutPrefix=$DIR/AlignedSTAR/$(basename $out1)


# Debug
echo $SoutPrefix

# STAR 
time STAR --runThreadN 24 \
    --genomeDir "$starindex" \
    --readFilesIn "$out1" "$out2" \
    --readFilesCommand zcat \
    --outFileNamePrefix "$SoutPrefix" \
    --outSAMtype BAM Unsorted \
    --chimSegmentMin 20 \
    --chimScoreMin 1 \
    --alignIntronMax 100000 \
    --outFilterMismatchNmax 4 \
    --alignTranscriptsPerReadNmax 100000 \
    --outFilterMultimapNmax 2 \
    --chimOutType Junctions SeparateSAMold


# circRNA_finder output
mkdir -p $DIR/crnaRes/circRNA_finder
filJunc=$DIR/crnaRes/circRNA_finder/${baseName}_filteredJunctions.bed
s_filJunc=$DIR/crnaRes/circRNA_finder/${baseName}_s_filteredJunctions.bed
s_filJunc_fw=$DIR/crnaRes/circRNA_finder/${baseName}_s_filteredJunctions_fw.bed
sortBam=$DIR/crnaRes/circRNA_finder/${baseName}.bam
sortBamIndex=$DIR/crnaRes/circRNA_finder/${baseName}.bam.bai

# circRNA_finder
perl $cfinder --starDir $DIR/AlignedSTAR --minLen 20 --outDir $DIR/crnaRes

# CircSplice output
mkdir -p $DIR/crnaRes/CircSplice
cspliceAS=$DIR/crnaRes/CircSplice/${baseName}.result.as
cspliceCIRC=$DIR/crnaRes/CircSplice/${baseName}.result.circ

# circsplice
perl $csplice ${SoutPrefix}Chimeric.out.sam $genome $cspliceFlat


