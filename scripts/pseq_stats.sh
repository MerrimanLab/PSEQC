#!/usr/bin/env bash
#
# Generate pseq output files.

PHENOTYPE=$1

if [[ $PHENOTYPE == "" ]]; then
    echo "Usage:  pseq_stats.sh <phenotype column name>"
    exit 1    
fi
# Load phenotype file
echo "RUNNING: Load phenotypes into Plink/seq"
pseq proj load-pheno --file /Users/smilefreak/resequencing/combined_qc/11April2015/pheno/final_all_phenotypes.txt 
echo "COMPLETE: Load phenotypes into Plink/seq"
# Create genotype mean for cases and controls
mkdir -p qc

# Output raw counts
echo "RUNNING: Output raw counts"
pseq proj counts --phenotype $PHENOTYPE \
> qc/counts.txt
echo "COMPLETE: Output raw counts"
# Output raw pvalues
echo "RUNNING: Output raw pvalues"
pseq proj v-assoc --phenotype $PHENOTYPE \
> qc/pval_all.txt
echo "COMPLETE: Output raw pvalues"
# Output overall mean, DP and GQ for all
echo "RUNNING: GQM and DPM"
pseq proj v-view --mask no-vmeta  \
include="G=g(GQ); D=g(DP); GQM=mean( G ) ; DPM=mean( D ) " \
--vmeta --show GQM DPM --out qc/gqgm.stats  
# Output overall mean, DP and GQ for cases
pseq proj v-view --mask no-vmeta  \
phe=$PHENOTYPE:2 include="G=g(GQ); D=g(DP); GQM=mean( G ) ; DPM=mean( D ) " \
--vmeta --show GQM DPM --out qc/gqgm.cases.stats 
# Output overall mean, DP and GQ for controls
pseq proj v-view --mask no-vmeta  \
phe=$PHENOTYPE:1 include="G=g(GQ); D=g(DP); GQM=mean( G ) ; DPM=mean( D ) " \
--vmeta --show GQM DPM --out qc/gqgm.controls.stats 
echo "COMPLETE: GQM and DPM"
# Raw association for HWE
echo "RUNNING: Hwe calculation"
pseq proj v-assoc --phenotype $PHENOTYPE \
> qc/hwe_all.txt
echo "COMPLETE: Hwe calculation"

# variant frequencies
echo "RUNNING: Variant frequencies"
pseq proj v-freq --mask phe=$PHENOTYPE:2 > qc/cases.txt
pseq proj v-freq --mask phe=$PHENOTYPE:1 > qc/controls.txt
echo "COMPLETE: Variant frequencies"
# Annotate coding sites
echo "RUNNING: Variant effect" 
awk ' NR > 1 {print $1, $2} ' OFS="\t" qc/counts.txt | tr '/' '\t' > site_list.txt
pseq . lookup --seqdb ~/pseq/hg19/seqdb --locdb ~/pseq/hg19/locdb --annotate refseq\
    --file site_list.txt --out variant_effect.txt

awk ' BEGIN { print "VAR\tANNOT" } $2 == "worst" { print $1,$3} ' OFS="\t" \
variant_effect.txt.meta > qc/annot_all_variants.txt
echo "Complete: Variant effect" 
# Genotype matrix
echo "RUNNING: Genotype matrix"
pseq proj v-meta-matrix --name GQ  > qc/genotype_quality.txt
cat qc/genotype_quality.txt  | awk ' NR>1 { c10=0;c50=0; for(i =2; i <=NF; i++){  if( $i < 10 || $i == "NA" ) c10++; if( $i < 50 || $i == "NA" ) c50++ } ; print $1,c10,c50 } ' > qc/count_bad_good.txt
pseq proj v-meta-matrix --name DP  > qc/genotype_depth.txt
echo "COMPLETE: Genotype matrix"

echo "RUNNING: Allelic balance"
pseq proj allelic-balance --phenotype $PHENOTYPE  > qc/site.ab.summ
pseq proj allelic-balance --mask phe=$PHENOTYPE:2  > qc/site.cases.ab.summ
pseq proj allelic-balance --mask phe=$PHENOTYPE:1  > qc/site.controls.ab.summ
echo "COMPLETE: Allelic balance"

echo "RUNNING: GQ and GM awk commands processing data for further processing"
cat qc/gqgm.stats.vars | awk ' { print $1,$3,$6,$8 } '  | tr ';' '\t' | tr '=' '\t' | awk ' { printf $1"\t"$2"\t"$3"\t"$5"\t"$7"\n" }  ' | awk ' NF > 4' > qc/gqgm.stats
cat qc/gqgm.cases.stats.vars | awk ' { print $1,$3,$6,$8 } '  | tr ';' '\t' | tr '=' '\t' | awk ' { printf $1"\t"$2"\t"$3"\t"$5"\t"$7"\n" }  ' | awk ' NF > 4' > qc/gqgm.cases.stats
cat qc/gqgm.controls.stats.vars | awk ' { print $1,$3,$6,$8 } '  | tr ';' '\t' | tr '=' '\t' | awk ' { printf $1"\t"$2"\t"$3"\t"$5"\t"$7"\n" }  ' | awk ' NF > 4' > qc/gqgm.controls.stats    
echo "Complete: GQGM awk commands"

