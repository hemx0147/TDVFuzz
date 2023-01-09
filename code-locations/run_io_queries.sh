#!/bin/env bash

##
# Run codeql I/O queries & store results as individual .csv files as well as one combined summary file.
#
# Usage: run_io_queries.sh QLDB QLPACK
#
# Parameters:
#   QLDB      The CodeQL database that is to be analyzed
#   QLPACK    Directory containing the codeql queries
##
# Requires codeql binary to be available in PATH.
##

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
[[ "$#" -ne 2 ]] && fatal "invalid number of input arguments (expected 2, given $#)"

QLDB="$1"
QLPACK="$2"
[[ -d "$QLDB" ]] || fatal "invalid path to codeql database file \"$QLDB\""
[[ -d "$QLPACK" ]] || fatal "invalid path to qlpack directory \"$QLPACK\""


RES_DIR="./results"
[[ -d "$RES_DIR" ]] || mkdir "$RES_DIR"

# run all queries against database
OUTFILE="$RES_DIR/tdvf-io.csv"
codeql database analyze "$QLDB" "$QLPACK" --format=csv --output="$OUTFILE" --rerun

# write results of previous queries in individual result files
for query in $(ls "$QLPACK" | grep "\.ql$")
do
  COMP_BASE_NAME=$(basename "$query")
  COMP_NAME="${COMP_BASE_NAME%.*}"
  COMP_FILE="$COMP_NAME.csv"
  codeql database analyze "$QLDB" "$QLPACK/$query" --format=csv --output="$RES_DIR/$COMP_FILE"
done
