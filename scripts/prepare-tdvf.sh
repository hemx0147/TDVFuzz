#!/bin/env bash

# Copy TDVF image into the fw-images folder and create a symlink in the repo
# root for the fuzzer to run.
# requires to be run from within kafl environment

# Usage: ./prepare-tdvf.sh [IMAGE_SUFFIX]

# Parameters
# IMAGE_SUFFIX  A string of characters that is appended to the TDVF basename (default: "_EDK")
#               e.g. specifying the suffix "_kafl" will yield the image name"TDVF_kafl.fd"

# exit with errorcode 1
# optional argument: print error message.
function fatal()
{
    [[ -n "$1" ]] && echo "Error: $1"; echo
    exit 1
}

SUFFIX="_EDK"
[[ $# -gt 0 ]] && SUFFIX="$1"

FW_DIR=$BKC_ROOT/fw-images
[[ -z $TDVF_ROOT ]] && fatal "Could not find TDVF_ROOT. Verify that kAFL environment is set up."
[[ -z $BKC_ROOT ]] && fatal "Could not find BKC_ROOT. Verify that kAFL environment is set up."
[[ -z $FW_DIR ]] && fatal "Could not find fw-images dir in BKC_ROOT."

# copy TDVF image
IMG=$(find $TDVF_ROOT -type f -name "OVMF.fd")
IMG_COPY="$FW_DIR/TDVF$SUFFIX.fd"
[[ -z $IMG ]] && fatal "Could not locate TDVF image in TDVF_ROOT."
cp $IMG $IMG_COPY

# create symlink
ln -sf $IMG_COPY "$BKC_ROOT/TDVF.fd"