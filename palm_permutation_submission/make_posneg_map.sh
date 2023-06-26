#!/bin/bash
#############################
# make_posneg_map.sh
# 2022.10.26
# dan leopold (dale9688)
# ---------------------------
# description:
# - thresholds and adds pos (c1) and neg (c2) palm output maps into single map
#############################

topdir=/pl/active/banich/studies/ldrc/analysis/palm
cd $topdir
mkdir -p pos_neg_maps

#############################
# INPUTS
#############################

maptype=cft3.1_tfce_tstat_cfwep

# NOTE: only works for maps that have directional contrasts (i.e., _c1 and _c2)

for map in \
 noncircle-circleratio_cope1; \
 do

#############################
# COMMANDS
#############################

	fslmaths $topdir/output/fmri/${map}/${map}_${maptype}_c1.nii.gz -thr 1.301 temp_c1.nii.gz
	fslmaths $topdir/output/fmri/${map}/${map}_${maptype}_c2.nii.gz -thr 1.301 temp_c2.nii.gz
	fslmaths temp_c2.nii.gz -mul -1 temp_c2_neg.nii.gz
	fslmaths temp_c1.nii.gz -add temp_c2_neg.nii.gz $topdir/pos_neg_maps/${map}_${maptype}_c1c2.nii.gz
	rm temp_c1.nii.gz temp_c2.nii.gz temp_c2_neg.nii.gz
	echo "${map}_c1c2 map complete"
done

#############################
