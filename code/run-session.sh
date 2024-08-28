#!/bin/bash

SESSION=$1

DATASET_NAME=HCPh
DATASET_PATH=/data/datasets/hcph
OUTPUT_PATH=/data/derivatives/hcph/datalad/hcph-mriqc/
WORKDIR=$HOME/tmp/mriqc_ses-$SESSION

mkdir -p $WORKDIR

# Generate filter file
FILTER_FILE=${WORKDIR}/filter-$SESSION.json
sed -e "s/sesid/$SESSION/g" code/filters-tpl.json > $FILTER_FILE

# Git/datalad
git checkout master
datalad update --how ff-only
git checkout -b add/ses-${SESSION}

# Prepare execution
pushd $WORKDIR
source activate fmriprep

# Execute MRIQC
mriqc ${DATASET_PATH} ${OUTPUT_PATH} participant --participant-label 001 --nprocs 20 --omp-nthreads 12 -w $WORKDIR -vv --bids-database-dir ${DATASET_PATH}/.bids-index/ --dsname ${DATASET_NAME} --no-sub --bids-filter-file $FILTER_FILE && rm -rf $WORKDIR
popd

# Git/datalad
datalad save -m "add: $SESSION"
datalad push --to=ria-storage
datalad push --to=origin

# Send PR
gh pr create -B "master" -r "@celprov" -a "@me" -t "ADD: MRIQC for $SESSION" -b "Automatically generated PR with MRIQC results for session $SESSION"




