#!/bin/bash
#############################
# tstat_cluster_results.sh
# 2022.10.26
# dan leopold (dale9688)
# ---------------------------
# description:
# - thresholds and adds pos (c1) and neg (c2) tstat maps into single map, masked by cfwep-thresholded results
#############################

topdir=/pl/active/banich/studies/ldrc/analysis
cd $topdir/FEAT/nback_paper
mkdir -p tstat_cluster_maps

#############################
# INPUTS
#############################

masktype=cft3.1_tfce_tstat_cfwep
maptype=cft3.1_tfce_tstat

for map in \
 nback_cope5 \
 nback_cope10 \
 nback_cope16 \
 nback_cope17 \
 nback_cope18 \
 nback_cope20 \
 nback_cope21 \
 nback_cope22 \
 nback_cope24; \
 do

#############################
# COMMANDS
#############################

	fslmaths $topdir/palm/output/fmri/${map}/${map}_${masktype}_c1.nii.gz -thr 1.301 -bin temp_c1.nii.gz
	fslmaths $topdir/palm/output/fmri/${map}/${map}_${masktype}_c2.nii.gz -thr 1.301 -bin temp_c2.nii.gz
	fslmaths temp_c1.nii.gz -add temp_c2.nii.gz temp_c1c2.nii.gz
	
	fslmaths $topdir/palm/output/fmri/${map}/${map}_${maptype}_c1.nii.gz -add $topdir/palm/output/fmri/${map}/${map}_${maptype}_c2.nii.gz temp_tc1c2.nii.gz
	fslmaths temp_tc1c2.nii.gz -mas temp_c1c2.nii.gz ${topdir}/FEAT/nback_paper/tstat_cluster_maps/${map}_tstatmasked_c1c2.nii.gz

	rm temp_c1.nii.gz temp_c2.nii.gz temp_c1c2.nii.gz temp_tc1c2.nii.gz
	echo "${map}_c1c2 masked tstat map complete"

done

#############################
