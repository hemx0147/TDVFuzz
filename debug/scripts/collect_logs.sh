#!/bin/bash

# TODO: adapt this script to new repo structure

# Collect log files produced by kAFL.
# This script must be run from within the kAFL environment.

WORKDIR=~/tdvf-hello
SCRIPTS=$WORKDIR/scripts
[[ -d $WORKDIR ]] || fatal "Could not find $WORKDIR. Verify that directory exists."
[[ -d $SCRIPTS ]] || fatal "Could not find $SCRIPTS. Verify that directory exists."

echo "Collecting logfiles..."
LOG_DIR=$WORKDIR/logs
FINDINGS_DIR=$WORKDIR/findings

# create corresponding directories if not yet existing
[[ -d $WORKDIR ]] || mkdir $WORKDIR
[[ -d $LOG_DIR ]] || mkdir $LOG_DIR

# copy logs (overwrite by default)
rm -rf $LOG_DIR/* $FINDINGS_DIR
cp $KAFL_WORKDIR/*.log $LOG_DIR
cp -r $KAFL_WORKDIR/logs $FINDINGS_DIR