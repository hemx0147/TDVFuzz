#!/bin/env bash

# Copy TDVF image and create symlink for fuzzer to run
# requires to be run from within kafl environemtn


# exit with errorcode 1
# optional argument: print error message.
function fatal()
{
    [[ -n "$1" ]] && echo "Error: $1"; echo
    exit 1
}


FW_DIR=$BKC_ROOT/fw-images
[[ -z $TDVF_ROOT ]] && fatal "Could not find TDVF_ROOT. Verify that kAFL environment is set up."
[[ -z $BKC_ROOT ]] && fatal "Could not find BKC_ROOT. Verify that kAFL environment is set up."
[[ -z $FW_DIR ]] && fatal "Could not find fw-images dir in BKC_ROOT."

# copy TDVF image
IMG=$(find $TDVF_ROOT -type f -name "OVMF.fd")
IMG_COPY="$FW_DIR/TDVF_EDK.fd"
[[ -z $IMG ]] && fatal "Could not locate TDVF image in TDVF_ROOT."
cp $IMG $IMG_COPY

# create symlink
ln -sf $IMG_COPY "$BKC_ROOT/TDVF.fd"