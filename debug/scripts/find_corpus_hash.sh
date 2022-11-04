#!/bin/env bash

##
# Find a kAFL corpus that produced a crash/kasan/timeout in a kAFL session.
# This script must be run from within the kAFL environment.
#
# Usage: find_corpus.sh [OPTION] FILE
#
# Options:
#   -h, --help    Display this help text
#   -w WORKDIR    The kAFL working directory with logs/, metadata/ and corpus/
#                 directories (default: KAFL_WORKDIR)
#
# Parameters:
#   FILE    A kAFL findings file with part of corpus hash in filename,
#           e.g. kasan_<hash>.log or crash_<hash>.log
##
# This script uses the partial corpus hash given in a kAFL findings file (e.g.
# crash_<hash>.log) to find a matching corpus file from metadata given in the
# metadata/ directory.
# The procedure may take a few minutes to finish since it's using the mcat.py
# tool to parse the metadata information.
##


####################################
# Global Variables
####################################
WORKDIR=$KAFL_WORKDIR
FND_NAME=""

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

# only print if VERBOSE flag is set
function verbose_print()
{
    [[ $VERBOSE -eq 1 ]] && echo $1
}


function fatal_no_corpus() {
    fatal "Partial hash from $1 matches hash $2 from $3 but payload could not be found in $4."
}



####################################
# Main()
####################################

# check if findings file exists
# grep partial hash from findings file
# extract readable metadata info from metadata files & remember name of metadata file (same name as corpus)
# if partial hash found in metadata content then return metadata file name

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
        '-v')
            VERBOSE=1
            shift   # past argument
            ;;
        -*|--*)
            fatal "Unknown option $1"
            ;;
        *)
            POSITIONAL_ARGS+=("$1") # save positional arg
			[[ -z "$1" ]] && fatal "Missing parameter FILE"
			FND_NAME=$(basename "$1")
            shift   # past argument
            ;;
    esac
done
set -- "${POSITIONAL_ARGS[@]}"  # restore positional parameters

# test if in KAFL environment
[[ -z "$BKC_ROOT" ]] && fatal "Could not find BKC_ROOT. Verify that kAFL environment is set up."
[[ -z "$KAFL_ROOT" ]] && fatal "Could not find KAFL_ROOT. Verify that kAFL environment is set up."


# test if necessary directories exist
LOGS=$(realpath $WORKDIR/logs)
CORPUS_BASE=$(realpath $WORKDIR/corpus)
CORPUS=$(realpath $CORPUS_BASE/$FND_TYPE)
METADATA=$(realpath $WORKDIR/metadata)
[[ -d $WORKDIR ]] || fatal "Could not find kafl working directory $WORKDIR"
[[ -d $LOGS ]] || fatal "Could not find logs/ folder in $WORKDIR."
[[ -d $CORPUS_BASE ]] || fatal "Could not find corpus/ folder in $WORKDIR."
[[ -d $METADATA ]] || fatal "Could not find metadata/ folder in $WORKDIR."

FND_PATH=$LOGS/$FND_NAME
FND_TYPE=$(echo $FND_NAME | sed 's/_.*//')  # type of finding (crash/kasan/timeout)
[[ -f $FND_PATH ]] || fatal "Could not find findings file $FND_NAME in $LOGS."
[[ -d $CORPUS ]] || fatal "Could not find $FND_TYPE/ folder in $CORPUS_BASE."

# grep partial hash from findings file
FND_HASH=$(echo $FND_NAME | sed 's/.*_//' | tr -d ".log" )
# echo "$FND_HASH"

# extract readable info from metadata files & match corpus hash to node
for node in $(ls $METADATA)
do
    # echo "checking $node"
    PAYLOAD=$(echo $node | sed 's/node/payload/')
    CORPUS_HASH=$(mcat.py $METADATA/$node | grep "hash" | cut -c 20-35)
    
    # echo "$CORPUS_HASH"
    if [[ $CORPUS_HASH == *"$FND_HASH"* ]]
    then
        # echo "matching hash found: $PAYLOAD"
        match=$(find $CORPUS_BASE -type f -name $PAYLOAD)
        [[ -z "$match" ]] && fatal_no_corpus $FND_NAME $CORPUS_HASH $PAYLOAD $CORPUS
        # echo "$PAYLOAD: $CORPUS_HASH ($CORPUS/$PAYLOAD)"
        echo "$match"
        exit 0
    fi
done

echo "loop done"
fatal_no_corpus $FND_NAME $CORPUS_HASH $PAYLOAD $CORPUS