#!/bin/bash

###
# Lists corpi and their matching hashes.
# Script must be run from within kAFL environment.
# Note that this script may take a while to finish. This is due to mcat.py being slow.
# 
# @param 1 workdir	The kAFL working directory including a metadata/ folder
#
# @return A list of format <corpus_name>: <corpus_hash>
###


function fail {
	echo
	echo -e "$1"
	echo
	echo -e "Usage:\n\t$0 <kafl_workdir>"
	echo
	exit 1
}


########## MAIN CODE ##########

# test if in KAFL environment
[[ -z "$BKC_ROOT" ]] && fail "Could not find BKC_ROOT. Verify that kAFL environment is set up."
[[ -z "$KAFL_ROOT" ]] && fail "Could not find KAFL_ROOT. Verify that kAFL environment is set up."

# command line parsing
[[ $# -eq 1 ]] || fail "Missing arguments."

KAFL_WORKDIR=$(realpath $1)	# kAFL work dir with logs/, corpus/ & metdadata/ folders

METADATA=$KAFL_WORKDIR/metadata

[[ -d $METADATA ]] || fail "Could not find metadata/ folder in workdir $KAFL_WORKDIR."

# extract readable metadata from metadata files & match corpus hash to node
for node in $(ls $METADATA)
do
	PAYLOAD=$(echo $node | sed 's/node/payload/')
	CORPUS_HASH=$(mcat.py $METADATA/$node | grep "hash" | cut -c 20-35)
	echo "$PAYLOAD: $CORPUS_HASH"
done