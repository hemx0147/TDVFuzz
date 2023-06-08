#!/bin/env bash

##
# Clean a CodeQL results .csv file by removing unnecessary columns and quotes
# and by introducing column headers to make results more readable.
#
# Usage: clean_results.sh FILE
#
# Parameters:
#   FILE    Path to the CodeQL results .csv file (default: results/tdvf-virtio.csv)
##
##

RES_DIR="./results"
RESULTS="$RES_DIR/tdvf-virtio.csv"

# print script usage information given above in comments
function usage()
{
  # find usage line
    usage_start=$(grep -n "^# Usage" "$0" | awk -F ":" '{print $1}')
    # print only usage part
    tail -n +"$usage_start" "$0" | sed -ne '/^#/!q;/^##/q;s/.\{1,2\}//;p'
    exit
}

# exit with errorcode 1 & print usage.
# optional argument: print error message.
function fatal()
{
    [[ -n "$1" ]] && echo "Error: $1"; echo
    usage >&2
    exit 1
}


### MAIN ###
[[ -n "$1" ]] && RESULTS=$(realpath "$1")
[[ -d $RES_DIR ]] || fatal "no such file or directory \"$RES_DIR\""
[[ -f $RESULTS ]] || fatal "no such file or directory \"$RESULTS\""


# create column headers in tmp file
RES_TMP=$(basename $RESULTS)".tmp"
echo "Query,Result,Filepath,Startline,Startcolumn,Endline,Endcolumn" > $RES_TMP

# remove unnecessary columns 2 (description) and 3 (severity)
# replace spaces by ',' and remove quotes
# remove first '/' from file path
# append cleaned data to tmp restuls file
cat $RESULTS | awk -F',' '{$2=$3=""; print $0}' | sed 's/\"\ \+\"/,/g' | sed 's/,\//,/' | tr -d '"' >> $RES_TMP

# replace original results file with the cleaned one
mv $RES_TMP $RESULTS