#!/bin/env bash

##
# Find & print occurences of IO Read/Write functions in given directory.
#
# Usage: find_io_functions.sh SEARCHDIR
#        find_io_functions.sh -v SEARCHDIR
#
# @param -v         print verbose output
# @param SEARCHDIR  The directory where the search should be conducted
##


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
    echo "       find_io_functions.sh -v SEARCHDIR" >&2
    exit 1
}

# only print if VERBOSE flag is set
function verbose_print()
{
    [[ $VERBOSE -eq 1 ]] && echo "$1"
}


### MAIN ###
[[ "$#" -lt 1 || "$#" -gt 2 ]] && fatal "invalid number of input arguments (expected 1 or 2, given $#)"

VERBOSE=0
if [[ "$1" -eq "-v" ]]
then
    VERBOSE=1
    [[ -z "$2" ]] && fatal "missing argument: SEARCHDIR" || SEARCH_DIR="$2"
else
    SEARCH_DIR="$1"
fi

[[ -d "$SEARCH_DIR" ]] || fatal "invalid path to SEARCHDIR $SEARCH_DIR"

# search for R/W functions for different I/O components
for component in 'Cr' 'Msr' 'Mmio' 'Pio' 'PciIo' 'VirtIo'
do
    verbose_print "### ${component} ###"
    for action in 'Read' 'Write'
    do
        fname1="${action}${component}"
        find_occurences $SEARCH_DIR $fname1

        fname2="${component}${action}"
        find_occurences $SEARCH_DIR $fname2
    done

    # print empty line for better readability
    verbose_print ""
done