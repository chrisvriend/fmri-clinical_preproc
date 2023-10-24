#!/bin/bash 



module load FreeSurfer/7.4.1.bugfix-centos8_x86_64


bidsdir=/home/anw/cvriend/my-scratch/GOALS/bids
derivdir=/home/anw/cvriend/my-scratch/GOALS/GOALS_derivatives
freesurferdir=${derivdir}/freesurfer

subj=sub-GOALS20009

mkdir -p ${derivdir}/anat_deriv/${subj}/anat

mri_convert ${freesurferdir}/${subj}/mri/aparc+aseg.mgz --in_type mgz --out_type nii \
--out_orientation LAS ${derivdir}/anat/${subj}/anat/${subj}_desc-aparcaseg_dseg.nii.gz

mri_convert ${freesurferdir}/${subj}/mri/brainmask.mgz --in_type mgz --out_type nii \
--out_orientation LAS ${derivdir}/anat/${subj}/anat/${subj}_desc-brain_mask.nii.gz

echo '{"RawSources": ["${subj}_T1w.nii.gz"], "Type": "Brain"}' | jq . > ${derivdir}/anat/${subj}/anat/${subj}_desc-brain_mask.json

mri_convert ${freesurferdir}/${subj}/mri/T1.mgz --in_type mgz --out_type nii \
--out_orientation LAS ${derivdir}/anat/${subj}/anat/${subj}_desc-preproc_T1w.nii.gz

echo '{"SkullStripped": true}' | jq . > ${derivdir}/anat/${subj}/anat/${subj}_desc-preproc_T1w.json


# GM / WM / CSF segmentations probseg


mri_convert ${freesurferdir}/${subj}/mri/aseg.mgz --in_type mgz --out_type nii \
--out_orientation LAS ${derivdir}/anat/${subj}/anat/${subj}_desc-aseg_dseg.nii.gz

for int in 5 14 15 44 
