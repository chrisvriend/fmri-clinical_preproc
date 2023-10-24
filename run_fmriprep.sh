#!/bin/bash

## slurm settings ###
#SBATCH --job-name=fmriprep
#SBATCH --mem=16G
#SBATCH --partition=luna-cpu-short
#SBATCH --qos=anw-cpu
#SBATCH --cpus-per-task=8
#SBATCH --time=00-8:00:00
#SBATCH --nice=2000
#SBATCH --output fmriprep_%A.log
#SBATCH --mail-type=END,FAIL
##################################END SLURM CODE#######################################################

# usage instructions
Usage() {
    cat <<EOF


    (C) Chris Vriend - AmsUMC - 21-10-2023
    script to run fmriprep and use anatomical derivatives from
    previously run recon-all-clinical.
   
    Usage: sbatch GOALS_fmriprep.sh <bidsdir> <workdir> <derivativesdir> <subjID>  
    Obligatory:
    bidsdir = full path to bids directory that contains subject's anatomical file in bids format
    workdir = full path to directory where working files will be (temporarily) saved
    derivativesdir = full path to folder where the fmriprep output will be saved/created 
    subjID = subject ID according to BIDS (e.g. sub-1000)

    Optional:
	additional options and paths may need to be checked/modified in the script

EOF
    exit 1
}

[ _$4 = _ ] && Usage

# relevant paths for apptainer/fmriprep
export APPTAINER_BINDPATH="/opt/aumc-apps-eb/software,/scratch/anw/"
#fmripreppath=/opt/aumc-containers/apptainer/fmriprep/fmriprep-22.0.2.simg
fmripreppath=/opt/aumc-containers/apptainer/fmriprep/fmriprep-23.1.4.sif
fslicense=/opt/aumc-apps-eb/software/FreeSurfer/license.txt

#input variables
bidsdir=${1}
workdir=${2}
derivativesdir=${3}
subj=${4}

NCORES=8
NompCORES=8

##################
#### FMRIPREP ####
##################
subjbids=${subj#sub-*}

mkdir -p ${workdir} ${derivativesdir}/fmriprep
apptainer run --cleanenv ${fmripreppath} \
    ${bidsdir} ${derivativesdir}/fmriprep -w ${workdir} participant \
    --participant-label $(echo ${subjbids}) \
    --bold2t1w-dof 6 \
    --skip-bids-validation \
    --ignore flair t2w \
    --dummy-scans 4  \
    --fs-license-file=${fslicense} \
    --nthreads=${NCORES} \
    --omp-nthreads=${NompCORES} \
    --fs-subjects-dir ${derivativesdir}/freesurfer \
    --output-spaces func T1w
    # turned off 
    #--use-syn-sdc \
#    --fs-no-reconall 



echo "----------------"
echo "done with ${subj}"
echo "----------------"
