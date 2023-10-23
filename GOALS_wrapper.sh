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

# paths
bidsdir=/home/anw/cvriend/my-scratch/GOALS/bids
derivativesdir=/home/anw/cvriend/my-scratch/GOALS/derivatives
workdir=/home/anw/cvriend/my-scratch/GOALS/work
scriptdir=/home/anw/cvriend/my-scratch/GOALS/scripts

# mandatory inputs
subj=sub-GOALS20003 # subjID, starts with sub-* (bids compliant)
task=rest # functional image ID
denoise_protocol=24HMP8PhysSpikeReg # denoising strategy

#optional inputs
acq=acq-highres # anatomical acq ID
session=ses-T2 # session ID
run=run-1 # run ID

###########################
# check if files exist

if [ -z "$session" ]; then
    # sess empty
    sessionpath=/
    sessionfile=_
else
    sessionpath=/${session}/
    sessionfile=_${session}_
fi


if [ -z "$run" ]; then
    # run empty
    runfile=_
else
    runfile=_${run}_
fi

if [ -z "$acq" ]; then
    # acq empty
    acqfile=_
else
    acqfile=_${acq}_
fi

if [ ! -f ${bidsdir}/${subj}${sessionpath}anat/${subj}${sessionfile}${acqfile}T1w.nii.gz ]; then
    echo "ERROR! input anatomical scan does not exist"
    echo ${subj}${sessionfile}${acqfile}_T1w.nii.gz
    exit
fi
if [ ! -f ${bidsdir}/${subj}${sessionpath}func/${subj}${sessionfile}task-${task}${runfile}bold.nii.gz ]; then
    echo "ERROR! input functional scan does not exist"
    echo ${subj}${sessionfile}task-${task}${runfile}bold.nii.gz
    exit
fi
###########################

echo "run FreeSurfer"
sbatch --wait GOALS_reconall_clinical.sh ${bidsdir} ${derivativesdir} ${subj} ${session} ${acq}
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
sbatch --wait rsfmridenoise.sh ${derivativesdir} ${scriptdir} ${subj} ${task} ${denoise_protocol} ${session} ${run}

echo "warp atlases to FreeSurfer and extract timeseries"
sbatch --wait Atlas2FreeSurfer_sbatch.sh ${derivativesdir} ${subj} ${task} ${denoise_protocol} ${session} ${run}

echo "DONE with ${subj}"
