#!/bin/env bash

##
# Compare contents of two *common* subdirectories of different parent directories
#
# @param PARENT_DIR_1   The first parent directory
# @param PARENT_DIR_2   The second parent directory
# @param SUB_DIR        The common subdirectory existing in both parent directories
#                       (default: "./")
##


function usage()
{
    echo "Usage: $(basename $0) PARENT_1 PARENT_2 [SUBDIR]"
    exit 0
}

function fatal()
{
    [[ -n "$1" ]] && echo "Error: $1"; echo
    usage >&2
    exit 1
}


# default value of common subdirectory is last part of parent directory
SDIR="."

# input parsing
[[ "$#" -lt 2  || "$#" -gt 3 ]] && fatal "invalid number of arguments (expected 2 or 3, given $#)"

PDIR_1="$1"
PDIR_2="$2"
[[ -n "$3" ]] && SDIR="$3"

# check if given directories are valid
[[ -d "$PDIR_1" ]] || fatal "invalid path to PARENT_1 directory \"$PDIR_1\""
[[ -d "$PDIR_2" ]] || fatal "invalid path to PARENT_2 directory \"$PDIR_2\""
[[ -d "$SDIR" ]] || fatal "invalid path to SUB_DIR directory \"$SDIR\""


# create temporary files in /tmp
TMP_DIR="/tmp/dir-compare"
[[ -d $TMP_DIR ]] || mkdir $TMP_DIR

# compile summary of subdir in first parent
OUT_1="$TMP_DIR/1.du"
pushd "$PDIR_1/$SDIR" > /dev/null
du -ch > $OUT_1
popd > /dev/null

# compile summary of subdir in second parent
OUT_2="$TMP_DIR/2.du"
pushd "$PDIR_2/$SDIR" > /dev/null
du -ch > $OUT_2
popd > /dev/null

# print the difference
colordiff $OUT_1 $OUT_2