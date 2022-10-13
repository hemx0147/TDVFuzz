#!/bin/bash

###
# Find a matching corpus file for a given findings file (crash/kasan/timeout) that has a part of the corpus hash in its filename.
# Script must be run from within kAFL environment.
# Note that this script may take a while to finish. This is due to mcat.py being slow.
# Note also that this script is very similar to list_corpus_hashes script but uses an early exit strategy to find a desired payload faster.
# 
# @param 1 workdir			The kAFL working directory
#
# @param 2 findings_file	Findings file with part of corpus hash in filename,
#							e.g. kasan_<hash>.log or crash_<hash>.log
#
# @return corpus_name		Return the name of the corpus file whose hash matches the partial hash in the findings file name
#							e.g. node_<number>
###


function fail {
	echo
	echo -e "$1"
	echo
	echo -e "Usage:\n\t$0 <kafl_workdir> <findings_file>"
	echo
	exit 1
}

function fail_no_input() {
	fail "Partial hash from $1 matches hash $2 from $3 but file could not be found in $4."
}

########## MAIN CODE ##########

# check if findings file exists
# grep partial hash from findings file
# extract readable metadata info from metadata files & remember name of metadata file (same name as corpus)
# if partial hash found in metadata content then return metadata file name

# test if in KAFL environment
[[ -z "$BKC_ROOT" ]] && fail "Could not find BKC_ROOT. Verify that kAFL environment is set up."
[[ -z "$KAFL_ROOT" ]] && fail "Could not find KAFL_ROOT. Verify that kAFL environment is set up."


# command line parsing
[[ $# -eq 2 ]] || fail "Missing arguments."

KAFL_WORKDIR=$(realpath $1)	# kAFL work dir with logs/, corpus/ & metdadata/ folders
FND_NAME=$(basename $2)		# Name of the findings file (e.g. crash_xxxxx.log)

FND_TYPE=$(echo $FND_NAME | sed 's/_.*//')	# type of finding (crash/kasan/timeout)
LOGS=$KAFL_WORKDIR/logs
CORPI_BASE=$KAFL_WORKDIR/corpus
CORPI=$CORPI_BASE/$FND_TYPE
METADATA=$KAFL_WORKDIR/metadata
FND_PATH=$LOGS/$FND_NAME

[[ -d $LOGS ]] || fail "Could not find logs/ folder in $KAFL_WORKDIR."
[[ -d $CORPI_BASE ]] || fail "Could not find corpus/ folder in $KAFL_WORKDIR."
[[ -d $METADATA ]] || fail "Could not find metadata/ folder in $KAFL_WORKDIR."
[[ -f $FND_PATH ]] || fail "Could not find findings file $FND_NAME in $LOGS."
[[ -d $CORPI ]] || fail "Could not find $FND_TYPE/ folder in $CORPUS_BASE."


# grep partial hash from findings file
FND_HASH=$(echo $FND_NAME | sed 's/.*_//' | tr -d ".log" )

# extract readable metadata from metadata files & match corpus hash to node
for node in $(ls $METADATA)
do
	PAYLOAD=$(echo $node | sed 's/node/payload/')
	CORPUS_HASH=$(mcat.py $METADATA/$node | grep "hash" | cut -c 20-35)
	# echo "$node: $CORPUS_HASH"
	
	if [[ $CORPUS_HASH == *"$FND_HASH"* ]]
	then
		[[ -f $CORPI/$PAYLOAD ]] || fail_no_input $FND_NAME $CORPUS_HASH $PAYLOAD $CORPI
		echo "$PAYLOAD: $CORPUS_HASH ($CORPI/$PAYLOAD)"
		exit 0
	fi
done

fail_no_input $FND_NAME $CORPUS_HASH $PAYLOAD $CORPI