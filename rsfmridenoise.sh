#!/bin/bash


#SBATCH --job-name=fmridenoise
#SBATCH --mem=24G
#SBATCH --partition=luna-cpu-short
#SBATCH --qos=anw-cpu
#SBATCH --cpus-per-task=1
#SBATCH --time=00-0:30:00
#SBATCH --nice=2000
#SBATCH --output=fmridenoise_%A.log


# (C) Chris Vriend - AmsUMC - 16-12-2022
# script to denoise resting-state functional MRI data processed using fmriprep
# using one of several denoising strategies (see PIPELINE OPTIONS)
# the folder "denoised" is created in the func folder of the fmriprep output
# the denoised and smoothed output = ${subj}${sessionfile}task-${task}${runfile}space-${outputspace}_desc-preproc_bold-smooth_NR.nii.gz
# this denoised scan can be used for further processing
# a report folder is additionally created with a html file to show spatial maps of the denoising variables

# note some 'future' and 'Deprecation' warnings will be shown but this does not affect the results!


# usage instructions
Usage() {
    cat <<EOF


    (C) Chris Vriend - AmsUMC - 16-12-2022
    script to denoise resting-state functional MRI data processed using fmriprep
    using one of several denoising strategies (see PIPELINE OPTIONS)
    this denoised scan can be used for further processing (e.g. timeseries extraction, ICA or seed-based connectivity)
    Note some 'future' and 'Deprecation' warnings will be shown but this does not affect the results!

    Usage: sbatch ./rsfmridenoise_sbatch.sh <fmriprepdir> <scriptdir> <subjID> <task> <session> <run> 
    Obligatory:
    fmriprepdir = full path to fmriprep directory that contains subject's fmrirep output
    scriptdir = full path to location with find_motionoutlier.py script
    subjID = subject ID according to BIDS (e.g. sub-1000)
    task = ID of fmri scan, e.g. rest
    denoise_protocol = one of several denoising protocols to choose from: 
    24HMP8PhysSpikeReg
    24HMP8PhysSpikeReg4GS
    24HMPaCompCorSpikeReg 
    24HMPaCompCorSpikeReg4GS
    ICAAROMA8Phys
    ICAAROMA8Phys4GS

    Optional:
	session = session ID of fmriprep output, e.g. ses-T0. keep empty if there are no sessions
    run = run ID of fmri scan, e.g. run-1. keep empty if there are no runs

	additional options and paths may need to be checked/modified in the script

EOF
    exit 1
}

[ _$5 = _ ] && Usage


#####################
# PIPELINE OPTIONS
#####################
denoise_protocol=24HMP8PhysSpikeReg

#24HMP8PhysSpikeReg
#24HMP8PhysSpikeReg4GS
#24HMPaCompCorSpikeReg 
#24HMPaCompCorSpikeReg4GS
#ICAAROMA8Phys
#ICAAROMA8Phys4GS
######################


derivativesdir=${1}
scriptdir=${2}
fmriprepdir=${derivativesdir}/fmriprep

# input variables
subj=${3} # subject, sub-xxx
task=${4} # task, e.g. rest
denoise_protocol=${5}
sess=${6} # session, ses-TX
run=${7}  # run, run-X

if [ -z "$sess" ]; then
    # sess empty
    sessionpath=/
    sessionfile=_
else
    sessionpath=/${sess}/
    sessionfile=_${sess}_
fi

if [ -z "$run" ]; then
    # sess empty
    runfile=_
else
    runfile=_${run}_
fi

# load modules
module load fsl/6.0.6.5
module load Anaconda3/2023.03
synthstrip=/data/anw/anw-gold/NP/doorgeefluik/container_apps/synthstrip.1.2.sif

# activate denoiser environment
conda activate /scratch/anw/share/python-env/denoiserenv

###################
# input variables
###################
BBTHRESH=10                       # Brain background threshold
SKERN=6.0                         # Smoothing kernel (FWSE)
TR=1.8                            # repetition time of fMRI
Ndummy=3                          # number of dummy scans to remove
lpfilter=0.1                      # low pass filter | typical freq band =0.01 - 0.08 Hz
hpfilter=0.009                    # highpass filter
outputspace=T1w                   # output space

######################
# to add some color to the output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
NC='\033[0m'
######################


############## - START PROCESSING - ##############

if [ -d ${fmriprepdir}/${subj}${sessionpath}func ]; then

    # input filenames
    funcimage=${subj}${sessionfile}task-${task}${runfile}space-${outputspace}_desc-preproc_bold.nii.gz
    mean_func=${subj}${sessionfile}task-${task}${runfile}space-${outputspace}_boldref.nii.gz
    regressorfile=${subj}${sessionfile}task-${task}${runfile}desc-confounds_timeseries.tsv

    # define output filenames
    funcimagenodummy=${subj}${sessionfile}task-${task}${runfile}space-${outputspace}_desc-preproc_dummy_bold.nii.gz
    funcimagesmooth=${subj}${sessionfile}task-${task}${runfile}space-${outputspace}_desc-smooth_bold.nii.gz
    funcimageNR=${subj}${sessionfile}task-${task}${runfile}space-${outputspace}_desc-smooth_${denoise_protocol}_bold.nii.gz

    outputdir=${fmriprepdir}/${subj}${sessionpath}func

    if [ ! -f ${fmriprepdir}/${subj}${sessionpath}func/${funcimageNR} ]; then
        echo
        echo -e "${GREEN}--------------${NC}"
        echo -e "${GREEN}subj = ${subj}${NC}"
        echo -e "${GREEN}--------------${NC}"
        echo
        cd ${fmriprepdir}/${subj}${sessionpath}func

        ########################
        # remove dummy scans
        ########################

        Nvols=$(fslnvols ${funcimage})
        rvols=$(echo "${Nvols}-${Ndummy}" | bc -l)
        echo -e "${YELLOW}No. vols in original scan = ${Nvols}${NC}"
        lregfile=$(echo "${Ndummy}+2" | bc -l)

        if [ ! -f ${funcimagenodummy} ]; then
            echo -e "${BLUE}...removing dummy scans...${NC}"
            fslroi ${funcimage} ${funcimagenodummy} ${Ndummy} -1
            Dvols=$(fslnvols ${funcimagenodummy})
            echo -e "${YELLOW}No. vols in modified scan = ${Dvols}${NC}"
        fi

        # modify regressors file
        rm -f ${subj}${sessionfile}task-${task}${runfile}confounders-dummy.tsv
        cat ${regressorfile} | head -1 >${subj}${sessionfile}task-${task}${runfile}confounders-dummy.tsv
        echo "$(tail -n +${lregfile} ${regressorfile})" >>${subj}${sessionfile}task-${task}${runfile}confounders-dummy.tsv

        rows=$(cat ${subj}${sessionfile}task-${task}${runfile}confounders-dummy.tsv | wc -l)
        clines=$(echo "${rvols} + 1" | bc -l)

        if test ${rows} -ne ${clines} ||
            test $(fslnvols ${funcimagenodummy}) -ne ${rvols}; then
            echo -e "${RED}number of lines in regressor file does not match the number of functional volumes${NC}"
            exit
        fi

        unset rows clines rvols lregfile

        ######################################
        # PREPARE FOR SMOOTHING USING FSL SUSAN
        ######################################
        echo

        # Perform skullstrip on the mean_func data (=boldref)
        echo -e "${BLUE}skullstrip mean functional image${NC}"
        echo
        ${synthstrip} -i ${fmriprepdir}/${subj}${sessionpath}func/${mean_func} \
            -m ${fmriprepdir}/${subj}${sessionpath}func/mask.nii.gz
        echo
        # synthstrip does something weird to the header that leads to
        # warning messages in the next step. Therefore we clone the header
        # from the input image
        fslcpgeom ${fmriprepdir}/${subj}${sessionpath}func/${mean_func} \
            ${fmriprepdir}/${subj}${sessionpath}func/mask.nii.gz

        fslmaths ${fmriprepdir}/${subj}${sessionpath}func/${funcimagenodummy} \
            -mas ${fmriprepdir}/${subj}${sessionpath}func/mask.nii.gz \
            ${fmriprepdir}/${subj}${sessionpath}func/funcimage_BET

        echo -e "${BLUE}calculate parameters for SUSAN...${NC}"
        lowerp=$(echo "scale=6; $(fslstats ${fmriprepdir}/${subj}${sessionpath}func/funcimage_BET -p 2)" | bc)
        upperp=$(echo "scale=6; $(fslstats ${fmriprepdir}/${subj}${sessionpath}func/funcimage_BET -p 98)" | bc)

        p98thr=$(echo "scale=6; ($upperp-$lowerp)/${BBTHRESH}" | bc)

        # Use fslmaths to threshold the brain extracted data based on the highpass filter above
        # use "mask" as a binary mask, and Tmin to specify we want the minimum across time
        fslmaths ${fmriprepdir}/${subj}${sessionpath}func/funcimage_BET -thr ${p98thr} \
            -Tmin -bin ${fmriprepdir}/${subj}${sessionpath}func/pre_thr_mask -odt char

        fslmaths ${fmriprepdir}/${subj}${sessionpath}func/funcimage_BET \
            -mas ${fmriprepdir}/${subj}${sessionpath}func/pre_thr_mask \
            ${fmriprepdir}/${subj}${sessionpath}func/func_data_thresh
        # We now take this functional data , and create a "mean_func" image that is the mean across time (Tmean)
        fslmaths ${fmriprepdir}/${subj}${sessionpath}func/func_data_thresh -Tmean \
            ${fmriprepdir}/${subj}${sessionpath}func/mean_func

        # To run susan, FSLs tool for noise reduction, we need a brightness threshold.
        # Calculated using fslstats based on
        # https://neurostars.org/t/smoothing-images-by-susan-after-fmriprep/16453/4
        medint=$(fslstats ${fmriprepdir}/${subj}${sessionpath}func/funcimage_BET \
            -k ${fmriprepdir}/${subj}${sessionpath}func/pre_thr_mask -p 50)
        brightthresh=$(echo "scale=6; ((${medint}*0.75))" | bc)
        #echo "brightthreshold = ${brightthresh}"

        #####################
        # SUSAN SMOOTHING
        #####################

        ssize=$(echo "scale=11; ((${SKERN}/2.355))" | bc)

        if [ ! -f ${fmriprepdir}/${subj}${sessionpath}func/${funcimagesmooth} ]; then
            echo -e "${BLUE}...running SUSAN${NC}"
            # susan uses nonlinear filtering to reduce noise
            # by only averaging a voxel with local voxels which have similar intensity
            susan ${fmriprepdir}/${subj}${sessionpath}func/func_data_thresh \
                ${brightthresh} ${ssize} 3 1 1 \
                ${fmriprepdir}/${subj}${sessionpath}func/mean_func ${medint} \
                ${fmriprepdir}/${subj}${sessionpath}func/func_data_smooth
            # 3 means 3D smoothing
            # 1 says to use a local median filter
            # 1 says that we determine the smoothing area from 1 secondary image, "mean_func" and then we use the same brightness threshold for the secondary image.
            # prefiltered_func_data_smooth is the output image

            # Now we mask the smoothed functional data with the mask image, and overwrite the smoothed image.
            fslmaths ${fmriprepdir}/${subj}${sessionpath}func/func_data_smooth \
                -mas ${fmriprepdir}/${subj}${sessionpath}func/mask \
                ${fmriprepdir}/${subj}${sessionpath}func/func_data_smooth

            mv ${fmriprepdir}/${subj}${sessionpath}func/func_data_smooth.nii.gz \
                ${fmriprepdir}/${subj}${sessionpath}func/${funcimagesmooth}

        fi

        cd ${fmriprepdir}/${subj}${sessionpath}func

        ###############################
        # DEFINE CONFOUND REGRESSORS
        ##############################
        echo
        echo -e "${BLUE}define confound regressors of protocol: ${denoise_protocol}${NC}"
        echo
        if [[ ${denoise_protocol} == "ICAAROMA8Phys" \
        || ${denoise_protocol} == "ICAAROMA8Phys4GS" ]]; then

            aromaregressors=${subj}${sessionfile}task-${task}_AROMAnoiseICs.csv

            rm -f aroma_motion_regressors.txt
            OLDIFS=$IFS
            IFS=","

            for c in $(cat ${aromaregressors}); do

                if test $c -lt 10; then
                    cc=0${c}
                elif test $c -lt 100; then
                    cc=${c}
                fi

                echo aroma_motion_${cc} >>aroma_motion_regressors.txt

            done
            IFS=$OLDIFS

            # delim=""
            # for item in $(cat aroma_motion_regressors.txt); do
            #   printf "%s" "$delim$item" >>aroma_comma.txt
            #   delim=","
            # done

            AROMA=$(cat aroma_motion_regressors.txt)
            #rm aroma_comma.txt
            # determine despiking regressors

        elif [[ ${denoise_protocol} == "24HMP8PhysSpikeReg" ||
            ${denoise_protocol} == "24HMP8PhysSpikeReg4GS" ||
            ${denoise_protocol} == "24HMP8PhysSpikeRegGS" ]]; then

            ${scriptdir}/find_motionoutliers.py -dir ${fmriprepdir} \
            -subjid ${subj} -session ${sess} -task ${task} -run ${run}

            # delim=""
            # for item in $(cat ${subj}${sessionfile}motion_outliers.txt); do
            #     printf "%s" "$delim$item" >>motion_comma.txt
            #     delim=","
            # done

            # MOTIONOUT=$(cat motion_comma.txt)
            # rm -f motion_comma.txt

            echo -e "${YELLOW}number of motion outliers for despiking  = $(cat ${subj}${sessionfile}task-${task}${runfile}motion_outliers.txt | wc -l)${NC}"
            MOTIONOUT=($(cat ${subj}${sessionfile}task-${task}${runfile}motion_outliers.txt))
        elif [[ ${denoise_protocol} == "24HMP8Phys" || ${denoise_protocol} == "24HMP8PhysGS" || ${denoise_protocol} == "24HMP8Phys4GS" ]]; then
            :

        else
            echo -e "${RED}denoise protocol not defined${NC}"
            exit
        fi

        if [[ ${denoise_protocol} == "ICAAROMA8Phys" ]]; then
            confounds=$(echo "csf csf_derivative1 csf_derivative1_power2 csf_power2 white_matter white_matter_derivative1 white_matter_power2 white_matter_derivative1_power2 ${AROMA}")
        elif [[ ${denoise_protocol} == "ICAAROMA8Phys4GS" ]]; then
            confounds=$(echo "global_signal global_signal_derivative1 global_signal_power2 global_signal_derivative1_power2 csf csf_derivative1 csf_derivative1_power2 csf_power2 white_matter white_matter_derivative1 white_matter_power2 white_matter_derivative1_power2 ${AROMA}")
        elif [[ ${denoise_protocol} == "24HMP8PhysSpikeReg" ]]; then
            if [ -z ${MOTIONOUT} ]; then
                confounds=$(echo "csf csf_derivative1 csf_derivative1_power2 csf_power2 white_matter white_matter_derivative1 white_matter_power2 white_matter_derivative1_power2 trans_x trans_x_derivative1 trans_x_power2 trans_x_derivative1_power2 trans_y trans_y_derivative1 trans_y_derivative1_power2 trans_y_power2 trans_z trans_z_derivative1 trans_z_derivative1_power2 trans_z_power2 rot_x rot_x_derivative1 rot_x_derivative1_power2 rot_x_power2 rot_y rot_y_derivative1 rot_y_derivative1_power2 rot_y_power2 rot_z rot_z_derivative1 rot_z_derivative1_power2 rot_z_power2")
            else
                confounds=$(echo "csf csf_derivative1 csf_derivative1_power2 csf_power2 white_matter white_matter_derivative1 white_matter_power2 white_matter_derivative1_power2 trans_x trans_x_derivative1 trans_x_power2 trans_x_derivative1_power2 trans_y trans_y_derivative1 trans_y_derivative1_power2 trans_y_power2 trans_z trans_z_derivative1 trans_z_derivative1_power2 trans_z_power2 rot_x rot_x_derivative1 rot_x_derivative1_power2 rot_x_power2 rot_y rot_y_derivative1 rot_y_derivative1_power2 rot_y_power2 rot_z rot_z_derivative1 rot_z_derivative1_power2 rot_z_power2 ${MOTIONOUT}")
            fi
        elif [[ ${denoise_protocol} == "24HMP8PhysSpikeReg4GS" ]]; then
            if [ -z ${MOTIONOUT} ]; then
                confounds=$(echo "csf csf_derivative1 csf_derivative1_power2 csf_power2 white_matter white_matter_derivative1 white_matter_power2 white_matter_derivative1_power2 trans_x trans_x_derivative1 trans_x_power2 trans_x_derivative1_power2 trans_y trans_y_derivative1 trans_y_derivative1_power2 trans_y_power2 trans_z trans_z_derivative1 trans_z_derivative1_power2 trans_z_power2 rot_x rot_x_derivative1 rot_x_derivative1_power2 rot_x_power2 rot_y rot_y_derivative1 rot_y_derivative1_power2 rot_y_power2 rot_z rot_z_derivative1 rot_z_derivative1_power2 rot_z_power2 global_signal global_signal_derivative1 global_signal_power2 global_signal_derivative1_power2")
            else
                confounds=$(echo "csf csf_derivative1 csf_derivative1_power2 csf_power2 white_matter white_matter_derivative1 white_matter_power2 white_matter_derivative1_power2 trans_x trans_x_derivative1 trans_x_power2 trans_x_derivative1_power2 trans_y trans_y_derivative1 trans_y_derivative1_power2 trans_y_power2 trans_z trans_z_derivative1 trans_z_derivative1_power2 trans_z_power2 rot_x rot_x_derivative1 rot_x_derivative1_power2 rot_x_power2 rot_y rot_y_derivative1 rot_y_derivative1_power2 rot_y_power2 rot_z rot_z_derivative1 rot_z_derivative1_power2 rot_z_power2 global_signal global_signal_derivative1 global_signal_power2 global_signal_derivative1_power2 ${MOTIONOUT}")
            fi
        elif [[ ${denoise_protocol} == "24HMP8PhysSpikeRegGS" ]]; then
            if [ -z ${MOTIONOUT} ]; then
                confounds=$(echo "csf csf_derivative1 csf_derivative1_power2 csf_power2 white_matter white_matter_derivative1 white_matter_power2 white_matter_derivative1_power2 trans_x trans_x_derivative1 trans_x_power2 trans_x_derivative1_power2 trans_y trans_y_derivative1 trans_y_derivative1_power2 trans_y_power2 trans_z trans_z_derivative1 trans_z_derivative1_power2 trans_z_power2 rot_x rot_x_derivative1 rot_x_derivative1_power2 rot_x_power2 rot_y rot_y_derivative1 rot_y_derivative1_power2 rot_y_power2 rot_z rot_z_derivative1 rot_z_derivative1_power2 rot_z_power2 global_signal")
            else
                confounds=$(echo "csf csf_derivative1 csf_derivative1_power2 csf_power2 white_matter white_matter_derivative1 white_matter_power2 white_matter_derivative1_power2 trans_x trans_x_derivative1 trans_x_power2 trans_x_derivative1_power2 trans_y trans_y_derivative1 trans_y_derivative1_power2 trans_y_power2 trans_z trans_z_derivative1 trans_z_derivative1_power2 trans_z_power2 rot_x rot_x_derivative1 rot_x_derivative1_power2 rot_x_power2 rot_y rot_y_derivative1 rot_y_derivative1_power2 rot_y_power2 rot_z rot_z_derivative1 rot_z_derivative1_power2 rot_z_power2 global_signal ${MOTIONOUT[@]}")
            fi
        elif [[ ${denoise_protocol} == "24HMP8Phys" ]]; then
            confounds=$(echo "csf csf_derivative1 csf_derivative1_power2 csf_power2 white_matter white_matter_derivative1 white_matter_power2 white_matter_derivative1_power2 trans_x trans_x_derivative1 trans_x_power2 trans_x_derivative1_power2 trans_y trans_y_derivative1 trans_y_derivative1_power2 trans_y_power2 trans_z trans_z_derivative1 trans_z_derivative1_power2 trans_z_power2 rot_x rot_x_derivative1 rot_x_derivative1_power2 rot_x_power2 rot_y rot_y_derivative1 rot_y_derivative1_power2 rot_y_power2 rot_z rot_z_derivative1 rot_z_derivative1_power2 rot_z_power2")
        elif [[ ${denoise_protocol} == "24HMP8PhysGS" ]]; then
            confounds=$(echo "csf csf_derivative1 csf_derivative1_power2 csf_power2 white_matter white_matter_derivative1 white_matter_power2 white_matter_derivative1_power2 trans_x trans_x_derivative1 trans_x_power2 trans_x_derivative1_power2 trans_y trans_y_derivative1 trans_y_derivative1_power2 trans_y_power2 trans_z trans_z_derivative1 trans_z_derivative1_power2 trans_z_power2 rot_x rot_x_derivative1 rot_x_derivative1_power2 rot_x_power2 rot_y rot_y_derivative1 rot_y_derivative1_power2 rot_y_power2 rot_z rot_z_derivative1 rot_z_derivative1_power2 rot_z_power2 global_signal")
        elif [[ ${denoise_protocol} == "24HMP8Phys4GS" ]]; then
            confounds=$(echo "csf csf_derivative1 csf_derivative1_power2 csf_power2 white_matter white_matter_derivative1 white_matter_power2 white_matter_derivative1_power2 trans_x trans_x_derivative1 trans_x_power2 trans_x_derivative1_power2 trans_y trans_y_derivative1 trans_y_derivative1_power2 trans_y_power2 trans_z trans_z_derivative1 trans_z_derivative1_power2 trans_z_power2 rot_x rot_x_derivative1 rot_x_derivative1_power2 rot_x_power2 rot_y rot_y_derivative1 rot_y_derivative1_power2 rot_y_power2 rot_z rot_z_derivative1 rot_z_derivative1_power2 rot_z_power2 global_signal global_signal_derivative1 global_signal_power2 global_signal_derivative1_power2")

        else

            echo -e "${RED}pipeline for denoising not recognized${NC}"
            exit
        fi

        ###########################################################################
        # PERFORM DENOISING
        ###########################################################################

        if [ ! -f ${outputdir}/${funcimageNR} ]; then
            mkdir -p ${outputdir}/report
            cd ${fmriprepdir}/${subj}${sessionpath}func
            echo
            echo -e "${BLUE}denoising functional image${NC}"

            python ${scriptdir}/run_denoise.py ${funcimagesmooth} \
                ${fmriprepdir}/${subj}${sessionpath}func/${subj}${sessionfile}task-${task}${runfile}confounders-dummy.tsv \
                ${outputdir} \
                --lp_filter ${lpfilter} --hp_filter ${hpfilter} \
                --col_names ${confounds}

            temp=$(remove_ext ${funcimagesmooth})
            mv ${temp}_NR.nii.gz ${funcimageNR}
            unset temp
        fi

        unset ssize uppert brightthresh lowerp upperp p98thr medmcf

        # print confounds to json sidecar
        confounds2=$(printf '%s\n' ${confounds})
        confoundarray=$(printf '%s\n' ${confounds2[@]} | jq -R . | jq -s .)
        temp=$(remove_ext ${funcimageNR})
        echo "
      {
        \"Confounds\": ${confoundarray},
        \"Smoothed\":true,
        \"IntendedFor\": \"${funcimageNR}\"
      }
      " >${outputdir}/${temp}.json
        temp2=$(remove_ext ${funcimage})
        #combine json files into one
        echo "$(jq -s 'add' ${outputdir}/${temp}.json ${fmriprepdir}/${subj}${sessionpath}func/${temp2}.json)" >${temp}.json
        #update taskname tag
        taskvar="rest"
        echo "$(jq --arg urlarg "${taskvar}" '. += {"TaskName": $urlarg }' ${temp}.json)" >${temp}.json
        # update skull stripped tage
        echo "$(jq '.SkullStripped = true' ${temp}.json)" >${temp}.json
        unset temp
        # clean-up
        rm -rf ${fmriprepdir}/${subj}${sessionpath}func/func_data_smooth_usan_size.nii.gz \
            ${fmriprepdir}/${subj}${sessionpath}func/funcimage_BET.nii.gz \
            ${fmriprepdir}/${subj}${sessionpath}func/mean_func.nii.gz \
            ${fmriprepdir}/${subj}${sessionpath}func/report_template.html \
            ${fmriprepdir}/${subj}${sessionpath}func/func_data_thresh.nii.gz \
            ${fmriprepdir}/${subj}${sessionpath}func/mask.nii.gz \
            ${fmriprepdir}/${subj}${sessionpath}func/*temp.nii.gz \
            ${fmriprepdir}/${subj}${sessionpath}func/pre_thr_mask.nii.gz \
            ${fmriprepdir}/${subj}${sessionpath}func/report

        # optional
        # rm ${fmriprepdir}/${subj}${sessionpath}func/${funcimagesmooth} \

        echo -e "${GREEN}--------------------------${NC}"
        echo -e "${GREEN}denoising done for ${subj}${NC}"
        echo -e "${GREEN}--------------------------${NC}"

    fi # smdesnoised exist
    else 

    echo -e "${RED}${fmriprepdir}/${subj}${sessionpath}func" 
    echo -e "does not exist${NC}"

fi
