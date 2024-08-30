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
# Execute MRIQC
mriqc ${DATASET_PATH} ${OUTPUT_PATH} participant --participant-label 001 --nprocs 20 --omp-nthreads 12 -w $WORKDIR -vv --bids-database-dir ${DATASET_PATH}/.bids-index/ --dsname ${DATASET_NAME} --no-sub --bids-filter-file $FILTER_FILE && rm -rf $WORKDIR
popd

# Git/datalad
datalad save -m "add: $SESSION"
datalad push --to=ria-storage
datalad push --to=origin

# Prepare PR's body
body_file=$( mktemp )
echo "Automatically generated PR with MRIQC results for session $SESSION" > $body_file
echo '' >> $body_file
echo "Generated reports:" >> $body_file
echo '' >> $body_file
echo '```TSV' >> $body_file
ls sub-001_ses-${SESSION}_*.html >> $body_file
echo '```' >> $body_file

# Retrieve original issue number:
$gh_issue= $( gh search issues --match title --repo TheAxonLab/hcph-dataset --json number --jq .[0].number  -- is:open label:scan $SESSION )
if [ ! -z "$gh_issue" ]; then
    echo '' >> $body_file
    echo "Prompted-by: TheAxonLab/hcph-dataset#${gh_issue}." >> $body_file
fi

# Send PR
gh pr create -B "master" -r "celprov" -a "@me" -t "ADD: MRIQC for $SESSION" -F $body_file

