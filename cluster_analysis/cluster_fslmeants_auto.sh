#!/bin/bash
### Author: Dan Leopold (daniel.r.leopold@gmail.com)

### Determine cluster peaks in #condition (Symbolic2-0 nback), extract % signal change within subject-specific masks
### 5.31.22

source /pl/active/banich/studies/ldrc/scripts/NEW_STUDY_SETUP.txt
topdir=/pl/active/banich/studies/ldrc/analysis/FEAT
cd $topdir/cluster_analyses


### Variables for updating

condition=amodal2M0
thresh=8
cope_num=19
roi_diam=5
task=nback
group_dir=nback_126subj.age_gender_zcov.gfeat

### Find cluster peaks

cluster -i ${topdir}/group_analyses/nback/nback_126subj.age_gender_zcov.gfeat/cope${cope_num}.feat/stats/zstat1.nii.gz -t ${thresh} --mm -o ${condition}_thresh${thresh}_clusterreport --olmax=${condition}_thresh${thresh}_clustermax --scalarname=Z


### Make masks for fslmeants and - per each ROI - run fslmeants and place output into condition/threshold/cope-specific CSV

mkdir -p $topdir/cluster_analyses/${condition}_cope${cope_num}_thresh${thresh}_results/${condition}_cope${cope_num}_masks
mkdir -p $topdir/cluster_analyses/${condition}_cope${cope_num}_thresh${thresh}_results/${condition}_cope${cope_num}_roi_values

### Note: uniq -w 2 used to only select highest peak within each cluster (not all of the maxima within a cluster); if all maxima desired, use secondary line without uniq -w 2
#uniq -w 2 ${condition}_thresh${thresh}_clustermax | awk '(NR!=1) {print $3 "," $4 "," $5}' >> tmp
awk '(NR!=1) {print $3 "," $4 "," $5}' ${condition}_thresh${thresh}_clustermax >> tmp

while read -r line; do
   xcor=`echo $line | cut -d "," -f1`
   ycor=`echo $line | cut -d "," -f2`
   zcor=`echo $line | cut -d "," -f3`
   mkmask ${xcor} ${ycor} ${zcor} ${roi_diam}

   fslmeants -i $topdir/group_analyses/${task}/${group_dir}/cope${cope_num}.feat/filtered_func_data.nii.gz -m $topdir/cluster_analyses/sphere_${xcor}_${ycor}_${zcor}_d${roi_diam}vox.nii.gz -o roi_${xcor}_${ycor}_${zcor}_values.txt

   sed -i '1i '${xcor}_${ycor}_${zcor}'' roi_${xcor}_${ycor}_${zcor}_values.txt
done < tmp


### Make wide table of all ROIs (ordered same as subject order for group model)

paste -d "," roi*values.txt > summary_${condition}_thresh${thresh}_cope${cope_num}_fslmeants.csv


### Clean up working directory (i.e., cluster_analyses)

mv sphere*.nii.gz ${condition}_cope${cope_num}_thresh${thresh}_results/${condition}_cope${cope_num}_masks
mv roi*values.txt ${condition}_cope${cope_num}_thresh${thresh}_results/${condition}_cope${cope_num}_roi_values
mv summary* ${condition}_cope${cope_num}_thresh${thresh}_results
mv ${condition}_thresh${thresh}_* ${condition}_cope${cope_num}_thresh${thresh}_results
rm tmp
