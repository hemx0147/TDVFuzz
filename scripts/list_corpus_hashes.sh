#!/bin/env bash

##
# List kAFL corpora and their matching hashes.
# This script must be run from within the kAFL environment.
#
# Usage: list_corpus_hashes.sh [OPTION]
#
# Options:
#   -h, --help    Display this help text
#   -w WORKDIR    The kAFL working directory with logs/, metadata/ and corpus/
#                 directories (default: KAFL_WORKDIR)
##
# This script parses the metadata information from the WORKDIR metadata/
# directory to find matching corpora in the corpus/ directory.
# The procedure may take a few minutes to finish since it's using the mcat.py
# tool to parse the metadata information.
##


####################################
# Global Variables
####################################
WORKDIR=$KAFL_WORKDIR

####################################
# Function Definitions
####################################

# print help text given above in comments
function help()
{
    # find help-start line (indicated by two '#')
    help_start="`grep -n "^##" "$0" | head -n 1 | awk -F ":" '{print $1}'`"
    # print only help part
    tail -n +"$help_start" "$0" | sed -ne '/^#/!q;s/.\{1,2\}//;1d;p'
    exit
}

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


####################################
# Main()
####################################

# argument parsing
POSITIONAL_ARGS=()
while [[ "$#" -gt 0 ]]
do
    case "$1" in
        '-h'|'--help')
            help
            ;;
        '-w')
            [[ -z "$2" ]] && fatal "Missing parameter WORKDIR"
            WORKDIR="$2"
        	shift   # past argument
            shift   # past value
            ;;
        -*|--*)
            fatal "Unknown option $1"
            ;;
        *)
            POSITIONAL_ARGS+=("$1") # save positional arg
            shift   # past argument
            ;;
    esac
done
set -- "${POSITIONAL_ARGS[@]}"  # restore positional parameters

# test if in KAFL environment
[[ -z "$BKC_ROOT" ]] && fatal "Could not find BKC_ROOT. Verify that kAFL environment is set up."
[[ -z "$KAFL_ROOT" ]] && fatal "Could not find KAFL_ROOT. Verify that kAFL environment is set up."


METADATA=$WORKDIR/metadata
[[ -d $WORKDIR ]] || fatal "Could not find kafl working directory $WORKDIR"
[[ -d "$METADATA" ]] || fatal "Could not find metadata/ folder in $WORKDIR."

# extract readable metadata from metadata files & match corpus hash to node
for node in $(ls $METADATA)
do
	PAYLOAD=$(echo $node | sed 's/node/payload/')
	CORPUS_HASH=$(mcat.py $METADATA/$node | grep "hash" | cut -c 20-35)
	echo "$PAYLOAD $CORPUS_HASH"
done