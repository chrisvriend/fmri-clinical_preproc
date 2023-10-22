# GOALS_fmri
fmri processing, denoising and timeseries extraction scripts for GOALS project

C. Vriend - Amsterdam UMC - Oct 22 2023

This pipeline can be used to run FreeSurfer's recon-all clinical and subsequently fmriprep using this FreeSurfer as anatomical derivatives (partly). Thereafter the preprocessed fMRI can be denoised using the Denoiser tool v1.0.1 - https://github.com/arielletambini/denoiser The tool have been slightly modified to work with python 3.8 and 
requires specific versions of python packages (see requirements.txt) to run without errors, although deprecation warnings will still be produced. 

the following denoising pipelines are implemented:
24HMP8PhysSpikeReg
24HMP8PhysSpikeReg4GS
ICAAROMA8Phys
ICAAROMA8Phys4GS
for more info on these pipelines see 
https://fmridenoise.readthedocs.io/en/latest/pipelines.html
and the rsfmridenoise*.sh scripts ==> the main scripts to call.

thereafter atlases are warped to FreeSurfer space and timeseries are extracted from the denoised fMRI scan.

GOALS_wrapper.sh calls all other scripts. Scripts have been optimized for use on the luna server of Amsterdam UMC (in combination with SLURM)and require several inputs (see usage info in each script).

Paths and variables will need to be changed INSIDE the script to specify the denoising pipeline, number of dummy scans to remove, smoothing kernel, etc. 






