#!/bin/bash

# (C) Chris Vriend - AmsUMC - 23-10-2023

# resources named below are for each job in the array
#SBATCH --mem=1G
#SBATCH --partition=luna-cpu-long
#SBATCH --qos=anw-cpu
#SBATCH --cpus-per-task=1
#SBATCH --time=01-0:00:00
#SBATCH --nice=2000
#SBATCH --output=fmripreproc)%A_%a.log
#SBATCH --array=1-100%8 

# SLURM settings:
# change range of array depending on how many rows there are in the subjects.txt file.
# change number behind % to indicate how many subjects to run simultaneously.


# usage instructions
Usage() {
    cat <<EOF


    (C) Chris Vriend - AmsUMC - 25-10-2023
    

    Usage: sbatch ./initialize_slurmarray.sh <subjects> 
    Obligatory:
    subjects = full path to txt file with subjectIDs (starting with sub-*) in bids directory 
    (path should be specified in wrapper.4array) for which preprocessing pipeline should be run

    NOTES:
    change length of array + number of simultaenous subjects to run inside the script (row 13)


EOF
    exit 1
}

[ _$1 = _ ] && Usage


subjects=${1} # full path to txt file with subjectIDs

subj=$(sed -n "${SLURM_ARRAY_TASK_ID}p" ${subjects})
# random delay
duration=$((RANDOM % 30 + 2))
echo -e "INITIALIZING...(wait a sec)"
echo
sleep ${duration}

sbatch wrapper.4array ${subj}

