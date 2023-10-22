#!/bin/bash

#SBATCH --job-name=FS2tissue
#SBATCH --mem-per-cpu=4G
#SBATCH --partition=luna-cpu-short
#SBATCH --qos=anw-cpu
#SBATCH --cpus-per-task=1
#SBATCH --time=00-0:30:00
#SBATCH --nice=2000
#SBATCH -o fs2tissue_%A.log


# usage instructions
Usage() {
    cat <<EOF

    (C) Chris Vriend - AmsUMC - 21-10-2023
    replace fmriprep tissue segmentations by those determined 
    by FreeSurfer's recon-all-clinical  
   
    Usage: sbatch fs2tissue.sh <bidsdir> <derivativesdir> <scriptdir> <subjID> <task>  | <session> <run>
    Obligatory:
    bidsdir = full path to bids directory that contains subject's anatomical file in bids format
    derivativesdir = full path to folder where the freesurfer & fmriprep output is saved
    scriptdir = location of the accompanying python scripts (usually the current folder)
    subjID = subject ID according to BIDS (e.g. sub-1000)
    task = ID of fmri scan, e.g. rest

    Optional:
	session = session ID of fmriprep output, e.g. ses-T0. keep empty if there are no sessions
    run = run ID of fmri scan, e.g. run-1. keep empty if there are no runs


	additional options and paths may need to be checked/modified in the script

EOF
    exit 1
}

[ _$5 = _ ] && Usage

# source software
module load FreeSurfer/7.4.1-centos8_x86_64
module load fsl/6.0.6.5
module load ANTs/2.4.1
afnitools_container=/scratch/anw/share-np/AFNIr

# input variables
bidsdir=${1}
derivativesdir=${2}
scriptdir=${3}
subj=${4}
task=${5}
session=${6}
run=${7}              # run, run-X


outputspace=T1w # generally the correct space

freesurferdir=${derivativesdir}/freesurfer
fmriprepdir=${derivativesdir}/fmriprep
export APPTAINER_BINDPATH="${bidsdir},${freesurferdir},${fmriprepdir}"

if [ -z "$session" ]; then
    # sess empty
    sessionpath=/
    sessionfile=_
else
    sessionpath=/${session}/
    sessionfile=_${session}_
fi

if [ -z "$run" ]; then
	# sess empty
	runfile=_
else
	runfile=_${run}_
fi
#  convert mgz to nii and transform to T1w space
for desc in aparc+aseg aseg brainmask; do
    descname=${desc//+/}
    descname2=${descname//mask/}
    if [[ ${desc} == "brainmask" ]]; then suffix=mask; else suffix=dseg; fi

    mri_convert ${freesurferdir}/${subj}/mri/${desc}.mgz --in_type mgz --out_type nii \
        --out_orientation LAS ${fmriprepdir}/${subj}${sessionpath}anat/${desc}_temp.nii.gz
    antsApplyTransforms -d 3 -i ${fmriprepdir}/${subj}${sessionpath}anat/${desc}_temp.nii.gz \
        -r ${fmriprepdir}/${subj}${sessionpath}anat/${subj}${sessionfile}*GM_probseg.nii.gz \
        -n NearestNeighbor \
        -t ${fmriprepdir}/${subj}${sessionpath}anat/${subj}_${session}*_from-fsnative_to-T1w_mode-image_xfm.txt \
        -o ${fmriprepdir}/${subj}${sessionpath}anat/${subj}${sessionfile}desc-${descname2}_${suffix}.nii.gz
done

# mri_convert ${freesurferdir}/${subj}/mri/synthSR.raw.mgz --in_type mgz --out_type nii \
#     --out_orientation LAS ${bidsdir}/${subj}${sessionpath}anat/${subj}${sessionfile}desc-FSclin_rec-1mm_T1w.nii.gz

# clean up
rm ${fmriprepdir}/${subj}${sessionpath}anat/*_temp.nii.gz

## extract GM, WM and CSF tissue segmentations ##

cd ${fmriprepdir}/${subj}${sessionpath}anat/
# ventricles
fslmaths ${fmriprepdir}/${subj}${sessionpath}anat/${subj}${sessionfile}desc-aseg_dseg.nii.gz -mul 0 temp.nii.gz
for int in 4 5 14 15 43 44; do

    fslmaths ${fmriprepdir}/${subj}${sessionpath}anat/${subj}${sessionfile}desc-aseg_dseg.nii.gz \
        -thr ${int} -uthr ${int} -bin ${int}.nii.gz

    fslmaths temp.nii.gz -add ${int}.nii.gz temp.nii.gz
    rm ${int}.nii.gz

done
mv temp.nii.gz ventricles.nii.gz
fslmaths ${fmriprepdir}/${subj}${sessionpath}anat/${subj}${sessionfile}desc-aseg_dseg.nii.gz \
    -thr 24 -uthr 24 -bin CSF.nii.gz

fslmaths ventricles -add CSF ${fmriprepdir}/${subj}${sessionpath}anat/${subj}${sessionfile}label-CSF_dseg.nii.gz

# clean-up
rm ventricles.nii.gz CSF.nii.gz

# 2x eroded
fslmaths ${fmriprepdir}/${subj}${sessionpath}anat/${subj}${sessionfile}label-CSF_dseg.nii.gz -ero -ero \
    ${fmriprepdir}/${subj}${sessionpath}anat/${subj}${sessionfile}desc-eroded_label-CSF_dseg.nii.gz
# -------------------------------#
# white matter #
fslmaths ${fmriprepdir}/${subj}${sessionpath}anat/${subj}${sessionfile}desc-aseg_dseg.nii.gz -mul 0 temp.nii.gz
for int in 2 41 192 250 251 252 253 254 255; do

    fslmaths ${fmriprepdir}/${subj}${sessionpath}anat/${subj}${sessionfile}desc-aseg_dseg.nii.gz \
        -thr ${int} -uthr ${int} -bin ${int}.nii.gz

    fslmaths temp.nii.gz -add ${int}.nii.gz temp.nii.gz
    rm ${int}.nii.gz
done
mv temp.nii.gz ${fmriprepdir}/${subj}${sessionpath}anat/${subj}${sessionfile}label-WM_dseg.nii.gz

# 3x eroded
fslmaths ${fmriprepdir}/${subj}${sessionpath}anat/${subj}${sessionfile}label-WM_dseg.nii.gz -ero -ero -ero \
    ${fmriprepdir}/${subj}${sessionpath}anat/${subj}${sessionfile}desc-eroded_label-WM_dseg.nii.gz

# -------------------------------#
# grey matter #
fslmaths ${fmriprepdir}/${subj}${sessionpath}anat/${subj}${sessionfile}desc-aseg_dseg.nii.gz -mul 0 temp.nii.gz
for int in 3 42; do

    fslmaths ${fmriprepdir}/${subj}${sessionpath}anat/${subj}${sessionfile}desc-aseg_dseg.nii.gz \
        -thr ${int} -uthr ${int} -bin ${int}.nii.gz

    fslmaths temp.nii.gz -add ${int}.nii.gz temp.nii.gz
    rm ${int}.nii.gz
done
mv temp.nii.gz ${fmriprepdir}/${subj}${sessionpath}anat/${subj}${sessionfile}label-GM_dseg.nii.gz

# there is one run for this subject. keep in?

boldreffile=${fmriprepdir}/${subj}${sessionpath}func/${subj}${sessionfile}task-${task}${runfile}space-${outputspace}_boldref.nii.gz
boldfile=${fmriprepdir}/${subj}${sessionpath}func/${subj}${sessionfile}task-${task}${runfile}space-${outputspace}_desc-preproc_bold.nii.gz
# make backup
cp ${fmriprepdir}/${subj}${sessionpath}func/${subj}${sessionfile}task-${task}${runfile}desc-confounds_timeseries.tsv \
    ${fmriprepdir}/${subj}${sessionpath}func/${subj}${sessionfile}task-${task}${runfile}desc-orig-confounds_timeseries.tsv

for label in WM CSF; do
    labelfile=${fmriprepdir}/${subj}${sessionpath}anat/${subj}${sessionfile}desc-eroded_label-${label}_dseg.nii.gz

    apptainer run ${afnitools_container} 3dresample \
        -rmode NN \
        -input ${labelfile} \
        -master ${boldreffile} \
        -prefix \
        ${fmriprepdir}/${subj}${sessionpath}func/${subj}${sessionfile}space-${outputspace}_label-${label}_temp.nii.gz

    fslmeants -i ${boldfile} \
        --label=${fmriprepdir}/${subj}${sessionpath}func/${subj}${sessionfile}space-${outputspace}_label-${label}_temp.nii.gz \
        >${fmriprepdir}/${subj}${sessionpath}func/${subj}${sessionfile}label-${label}_temp.tsv

    if [[ ${label} == "WM" ]]; then labelid=white_matter; else labelid=${label}; fi

    ${scriptdir}/calc_tissue_derivatives.py ${fmriprepdir}/${subj}${sessionpath}func/${subj}${sessionfile}label-${label}_temp.tsv \
        ${fmriprepdir}/${subj}${sessionpath}func/${subj}${sessionfile}label-${label}_desc-confounds_timeseries.tsv \
        ${labelid,,}

    # replace cols in original confounds file
    ${scriptdir}/replace_confound_cols.py \
        ${fmriprepdir}/${subj}${sessionpath}func/${subj}${sessionfile}task-${task}${runfile}desc-confounds_timeseries.tsv \
        ${fmriprepdir}/${subj}${sessionpath}func/${subj}${sessionfile}label-${label}_desc-confounds_timeseries.tsv \
        ${fmriprepdir}/${subj}${sessionpath}func/${subj}${sessionfile}task-${task}${runfile}desc-confounds_timeseries.tsv
    rm ${fmriprepdir}/${subj}${sessionpath}func/${subj}${sessionfile}label-${label}_temp.tsv \
        ${fmriprepdir}/${subj}${sessionpath}func/${subj}${sessionfile}space-${outputspace}_label-${label}_temp.nii.gz

done
