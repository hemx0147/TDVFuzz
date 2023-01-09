#!/bin/env bash

##
# Grep wrapper script for finding functions in TDVF code
#
# Usage: find_functions.sh PATTERN SEARCHDIR
#        find_functions.sh -i PATTERN SEARCHDIR
#
# Parameters:
#   PATTERN      The grep search pattern for a function (supports regex)
#   SEARCHDIR    The directory where the search should be conducted
#   -i           Case-insensitive search
##
# The output of this script can be used as input for the populate_queries.py
# script to automatically create a codeql query pack with the found functions.
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

# find occureces of FN_PATTERN & extract function name
find_occurences() {
    pattern="$1"
    search_dir="$2"
    if [[ "$CASE_INSENSITIVE" -eq 1 ]]
    then
        find "${search_dir}" -type f -name "*.h" -exec grep -i -E "${pattern}" {} \; | tr -d ' (' | sort -r | uniq
    else
        find "${search_dir}" -type f -name "*.h" -exec grep -E "${pattern}" {} \; | tr -d ' (' | sort -r | uniq
    fi
}


### MAIN ###
[[ "$#" -ne 2 && "$#" -ne 3 ]] && fatal "invalid number of input arguments (expected 2 or 3, given $#)"

CASE_INSENSITIVE=0
if [[ "$1" = "-i" ]]
then
    CASE_INSENSITIVE=1
    PATTERN="$2"
    SEARCH_DIR="$3"
else
    PATTERN="$1"
    SEARCH_DIR="$2"
fi

[[ -z "$PATTERN" ]] && fatal "search pattern is empty"
[[ -d "$SEARCH_DIR" ]] || fatal "invalid path to SEARCHDIR \"$SEARCH_DIR\""


# echo "pattern: $PATTERN"
# echo "searchdir: $SEARCH_DIR"
find_occurences "$PATTERN" "$SEARCH_DIR"