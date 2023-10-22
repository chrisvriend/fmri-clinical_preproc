#!/bin/bash 

# (C) Chris Vriend - AmsUMC - 23-10-2023

#SBATCH --job-name=GOALS_wrapper
#SBATCH --mem=1G
#SBATCH --partition=luna-cpu-long
#SBATCH --qos=anw-cpu
#SBATCH --cpus-per-task=1
#SBATCH --time=01-0:00:00
#SBATCH --nice=2000
#SBATCH --output=GOALS_wrapper_%A.log


bidsdir=/home/anw/cvriend/my-scratch/GOALS/bids
derivativesdir=/home/anw/cvriend/my-scratch/GOALS/derivatives
workdir=/home/anw/cvriend/my-scratch/GOALS/work
scriptdir=/home/anw/cvriend/my-scratch/GOALS/scripts
subj=sub-GOALS20009
session=ses-T2
run=run-1

echo "run FreeSurfer" 
sbatch --wait GOALS_reconall_clinical.sh ${bidsdir} ${derivativesdir} ${subj} ${session}
echo
echo "run fmriprep" 
sbatch --wait GOALS_fmriprep.sh ${bidsdir} ${workdir} ${derivativesdir} ${subj}

##########################################################################################
# perhaps not necessary anymore.
# echo "replace tissue segmentations in fmriprep by those from FreeSurfer clinical" 
# echo 
# sbatch --wait fs2tissue.sh ${bidsdir} ${derivativesdir} ${scriptdir} ${subj} ${session} ${run}
##########################################################################################

echo "denoise functional images" 
sbatch --wait rsfmridenoise.sh ${derivativesdir} ${scriptdir} ${subj} rest 24HMP8PhysSpikeReg ${session} ${run}

echo "warp atlases to FreeSurfer and extract timeseries"  
sbatch --wait Atlas2FreeSurfer_sbatch.sh ${derivativesdir} ${subj} rest 24HMP8PhysSpikeReg ${session} ${run}


echo "DONE with ${subj}"





