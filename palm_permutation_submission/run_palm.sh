#!/bin/bash
#############################
# run_palm.sh
# 2022.08.01
# dan leopold (dale9688)
# ---------------------------
# description:
# - runs palm permutations testing on specified input (FEAT copes, Freesurfer vars, etc.)
# - uses fsl_sub to submit and log palm run, including necessary exchangeability blocks, design files (.con & .mat)
# - outputs z-stat p-value maps using desired cluster correction method
# ---------------------------
#############################

#############################
# inputs
#############################
study_setup=/pl/active/banich/studies/ldrc/scripts/NEW_STUDY_SETUP.txt
topdir=/pl/active/banich/studies/ldrc/analysis/palm

# analysis type:
functional="y" #y/n for analysis of fmri/FEAT data 
structural="n" #y/n for analysis of structural/Freesurfer data 
	area="n"
	thickness="n"
	lgi="n"
	volume="n" #y/n for use of non-parametric combination of area and thickness inputs to analyze volume as well
	struc_covar="n" #y/n for use of anatomical covariates (e.g., total SA for area, mean thick for thickness, mean LGI for LGI)
rm_inputs="n" #y/n for automatically deleting the 4D inputs for palm analysis

voi=nback_agegendervg_interaction_mfg_gamma1k # "variable of interest" name for labeling output directories based upon main analysis covariate
eb_dir=${topdir}/input/eb
eb_file=${eb_dir}/eb_nback126_agegendergrp.csv

# PERMUTATION METHOD, F-TESTS, VARIANCE GROUP, and ACCELERATION options
ise="y" #y/n for sign-flipping (assumes independent and symmetric errors (ISE))
ee="y" #y/n for permutations (assumes exchangeable errors (EE))

ftest="y" #y/n for inclusion of f-tests that need to be analyzed/permuted

vg="y" #y/n for inclusion of multiple variance groups in Feat GLM group column
accel="y" #y/n for running palm with (gamma) acceleration or without (i.e., 10K permutations/flips)


# IF FUNCTIONAL: location of input cope design and input files (note: directs palm to lower-level cope# within group model results)
cope=9
mask_dir=${topdir}/input/masks
gm_mask=mfg_mask.nii #alternatives: bin_wager_gm_mask.nii, lexd7mask.nii, wagerXgfeat_nback107_mask.nii.gz

	# MUST UPDATE DESIGN/FEAT group-level GLM DIRECTORY
task=nback
gfeat_dir=nback_126subj.agevg_gendergrp_interaction.gfeat


# IF STRUCTURAL: location of 4D input files, surfaces, etc.
area_dir=${topdir}/input/fwhm15
thickness_dir=${topdir}/input/fwhm15
lgi_dir=${topdir}/input/fwhm5
surf_dir=/projects/ics/software/freesurfer/7.1.0/subjects/fsaverage5/surf

# function for defining ${hemi}:
structural_inputs () {
	area_input=${hemi}_area_stack.mgh
	thickness_input=${hemi}_thick_stack.mgh
	lgi_input=${hemi}_lgi_stack.mgh	
}

# analysis specs:
cft_thresh_val=3.0902323
cft_thresh=3.1 # for output file directory naming
perm_num=10000

# directory structure AND PALM specs for analysis (e.g., 4D inputs, outputs, etc.):
if [[ "$ee" == "y" && "$ise" == "y" ]]; then
	method="-ee -ise"
elif [[ "$ee" == "y" && "$ise" == "n" ]]; then
	method="-ee"
elif [[ "$ee" == "n" && "$ise" == "y" ]]; then
	method="-ise"
else
	echo "error : permutations and/or sign-flipping must be selected"
fi

if [[ "$vg" == "y" ]]; then
	vgopt="-vg auto"
elif [[ "$vg" == "n" ]]; then
	vgopt=""
else
	echo "error : variance group option must be set to Y or N"
fi

if [[ "$functional" == "y" ]]; then
	log_dir=${topdir}/logs/fmri
	out_dir=${topdir}/output/fmri
	design_dir=${topdir}/../FEAT/group_analyses/${task}/${gfeat_dir}

	if [[ "$accel" = "n" ]]; then
		palm_specs="-logp -${method} ${vgopt} -T -C ${cft_thresh_val} -Cstat mass -fdr -corrcon -eb ${eb_file} -n ${perm_num}"
	elif [[ "$accel" = "y" ]]; then
		palm_specs="-logp ${method} ${vgopt} -T -C ${cft_thresh_val} -Cstat mass -corrcon -eb ${eb_file} -nouncorrected -accel gamma -n 1000" # FOR ACCELERATION, DROP -FDR, uncorrected, and -n PERM#:
	else
		echo "error: acceleration option must be set to Y or N"
	fi

elif [[ "$structural" == "y" ]]; then
	log_dir=${topdir}/logs/fs
	out_dir=${topdir}/output/fs
	design_dir=${topdir}/input/design_files

	if [[ "$accel" = "n" ]]; then
		palm_specs="-logp ${method} ${vgopt} -T -C ${cft_thresh_val} -Cstat mass -fdr -corrcon -corrmod ${npc_com} -eb ${eb_file} -n ${perm_num}"
	elif [[ "$accel" = "y" ]]; then
		palm_specs="-logp ${method} ${vgopt} -T -C ${cft_thresh_val} -Cstat mass -corrcon -corrmod ${npc_com} -eb ${eb_file} -nouncorrected -accel gamma -n 500" # FOR ACCELERATION, DROP -FDR, uncorrected, and -n PERM#
	else
		echo "error: acceleration option must be set to Y or N"	
	fi

else
	echo "error : functional or structural analysis must be Y; (log/out/design)_dir not set"
fi

#################
#
# LATER: Build AUTO-STACK for structural analyses into this section
#
#################

#############################
# environment configuration
#############################
source $study_setup
cd $topdir
mkdir -p ${log_dir}
mkdir -p ${out_dir}

PALMPATH=/pl/active/banich/examples/palm_toolbox/palm-alpha112
export PATH=${PALMPATH}:${PATH}

export FSL_SLURM_XNODE_NAME=bnode0101,bnode0102,bnode0103,bnode0104,bnode0105
export FSL_SLURM_NUM_CPU=2
export FSL_SLURM_UCB_ACCOUNT=blanca-ics-ldrc
export FSL_SLURM_PARTITION_NAME=blanca-ics
export FSL_SLURM_QUEUE_NAME=blanca-ics
export FSL_SLURM_WALLTIME_MINUTES=2880
export FSL_SLURM_MB_RAM=8G    #mem per cpu (RC sets to 1G/cpu, hence need to increase)

#############################
# fsl_sub command setup
#############################
fsl_sub_command_inputs () {
	if [[ "$structural" == "y" ]]; then
		if [[ "$struc_covar" == "y" ]]; then
			struc_covar_name="cov"
			if [[ "$area" == "y" ]]; then
				area_com="-i ${area_dir}/${area_input} -d ${design_dir}/${voi}_areatotal.mat -t ${design_dir}/${voi}_areatotal.con"
				area_name=area
			else
				area_com=""
				area_name=""
			fi

			if [[ "$thickness" == "y" ]]; then
				thickness_com="-i ${thickness_dir}/${thickness_input} -d ${design_dir}/${voi}_thickmean.mat -t ${design_dir}/${voi}_thickmean.con"
				thickness_name=thickness
			else
				thickness_com=""
				thickness_name=""
			fi

			if [[ "$lgi" == "y" ]]; then
				lgi_com="-i ${lgi_dir}/${lgi_input} -d ${lgi_dir}/${voi}_lgimean.mat -t ${design_dir}/${voi}_lgimean.con"
				lgi_name=lgi
			else
				lgi_com=""
				lgi_name=""
			fi
		else
			struc_covar_name="nocov"
			if [[ "$area" == "y" ]]; then
				area_com="-i ${area_dir}/${area_input} -d ${design_dir}/${voi}_nocov.mat -t ${design_dir}/${voi}_nocov.con"
				area_name=area
			else
				area_com=""
				area_name=""
			fi

			if [[ "$thickness" == "y" ]]; then
				thickness_com="-i ${thickness_dir}/${thickness_input} -d ${design_dir}/${voi}_nocov.mat -t ${design_dir}/${voi}_nocov.con"
				thickness_name=thickness
			else
				thickness_com=""
					thickness_name=""
				fi

			if [[ "$lgi" == "y" ]]; then
				lgi_com="-i ${lgi_dir}/${lgi_input} -d ${lgi_dir}/${voi}_nocov.mat -t ${design_dir}/${voi}_nocov.con"
				lgi_name=lgi
			else
				lgi_com=""
				lgi_name=""
			fi
		fi

		if [[ "$volume" == "y" ]]; then
			volume_com="-npc"
			volume_name="vol"
		else
			volume_com=""
			volume_name=""
		fi

		if [[ "$structural" == "y" ]]; then
			surf_com="-s ${surf_dir}/${hemi}.white ${surf_dir}/${hemi}.white.avg.area.mgh"
		else
			surf_com=""
		fi

	elif [[ "$functional" == "y" ]]; then
		
		if [[ "$ftest" == "y" ]]; then
			design_com="-d ${design_dir}/cope${cope}.feat/design.mat -t ${design_dir}/cope${cope}.feat/design.con -f ${design_dir}/cope${cope}.feat/design.fts"
		elif [[ "$ftest" == "n" ]]; then
			design_com="-d ${design_dir}/cope${cope}.feat/design.mat -t ${design_dir}/cope${cope}.feat/design.con"
		else
			echo "error: ftest selection must be Y or N"
		fi

	else
		echo "error: structural and functional are both N"
	fi
}


#############################
# logic flow
#############################
if [[ "$functional" == "y" && "$structural" == "y" ]]; then
	echo "error : choose either functional or structural analysis"
elif [[ "$structural" == "y" && "$lgi" == "y" && ( "$area" == "y" || "$thick" = "y" ) ]]; then
	echo "error : analyze lgi separately from other modalities"

elif [[ "$functional" == "y" ]]; then
	echo "analyzing functional inputs"
	fsl_sub_command_inputs
	mkdir -p ${out_dir}/${voi}_cope${cope}
	cd ${out_dir}/${voi}_cope${cope}
	fsl_sub -N ${voi}_cope${cope} -l $log_dir palm -i ${design_dir}/cope${cope}.feat/filtered_func_data.nii.gz ${design_com} -m ${mask_dir}/${gm_mask} -o ${out_dir}/${voi}_cope${cope}_cft${cft_thresh} -noniiclass ${palm_specs}

elif [[ "$structural" == "y" ]]; then
	echo "analyzing structural inputs"
	for hemi in lh rh; do
		structural_inputs
		fsl_sub_command_inputs
	    mkdir -p ${out_dir}/${voi}_${area_name}${thickness_name}${volume_name}${lgi_name}
	    cd ${out_dir}/${voi}_${area_name}${thickness_name}${volume_name}${lgi_name}
	    echo "fsl_sub -N ${voi}_${area_name}${thickness_name}${volume_name}${lgi_name} -l $log_dir palm -designperinput ${area_com} ${thickness_com} ${lgi_com} ${surf_com} ${volume_com} -o ${out_dir}/${voi}_${area_name}${thickness_name}${volume_name}${lgi_name}_${struc_covar_name}_cft${cft_thresh}_${hemi} ${palm_specs}"
	done
else
	echo "error : logic flow incorrectly configured"
fi

###########################################
# delete individual subject maps and masks
###########################################
if [[ "$rm_inputs" == "y" ]]; then
	echo "deleting inputs and masks"
	rm -r ${area_dir}/[lr]h_area_stack.mgh
	rm -r ${thickness_dir}/[lr]h_thickness_stack.mgh
	rm -r ${lgi_dir}/[lr]h_lgi_stack.mgh
fi

echo "job submitted successfully"
