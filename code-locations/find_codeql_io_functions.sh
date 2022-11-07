#!/bin/env bash

##
# Find & print occurences of IO Read/Write functions in given directory.
#
# Usage: find_io_functions.sh SEARCHDIR
#
# @param SEARCHDIR  The directory where the search should be conducted
##

# TODO: change output to only show function names
# TODO: add verbose option that shows more readable output

find_occurences() {
    search_dir="$1"
    fname="$2"
    find "${search_dir}" -name "*.h" -exec grep "^[[:alnum:]]*${fname}[[:alnum:]]*" {} \; | tr -d ' (' | sort -r | uniq
}


# exit with errorcode 1 & print usage.
# optional argument: print error message.
function fatal()
{
    [[ -n "$1" ]] && echo "Error: $1"; echo
    echo "Usage: find_io_functions.sh SEARCHDIR" >&2
    exit 1
}



### MAIN ###

[[ "$#" -ne 1 ]] && fatal "invalid number of input arguments (expected 1, given $#)"

SEARCH_DIR="$1"
[[ -d "$SEARCH_DIR" ]] || fatal "invalid path to SEARCHDIR $SEARCH_DIR"

# search for R/W functions for different I/O components
for component in 'Cr' 'Msr' 'Mmio' 'Pio' 'PciIo' 'VirtIo'
do
    echo "### ${component} ###"
    for action in 'Read' 'Write'
    do
        fname1="${action}${component}"
        find_occurences $SEARCH_DIR $fname1

        fname2="${component}${action}"
        find_occurences $SEARCH_DIR $fname2
    done
    echo
done