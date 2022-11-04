#!/bin/env bash

##
# Collect log files produced by kAFL fuzzing session.
#
# Usage: collect_logs.sh [OPTION]
#
# Options:
#   -h, --help    Display this help text
#   -l LOG_DIR     Save log files in directory LOG_DIR (default: ./logs)
#   -w WORKDIR    The kAFL working directory (default: KAFL_WORKDIR)
#   -f            Also copy fuzzer findings
##
# Log files include hprintf-, serial- & debug logs and will be copied to
# directory LOG_DIR (default: ./logs).
# Fuzzer findings include crashes, timeouts and other errors and 
# will be copied into directory LOG_DIR/findings.
##


####################################
# Global Variables
####################################
VERBOSE=0
COPY_FINDINGS=0
LOG_DIR="./logs"
WORKDIR="$KAFL_WORKDIR"


####################################
# Function Definitions
####################################

# print script usage information given above in comments
function usage()
{
    # find usage line
    usage_start=$(grep -n "^# Usage" "$0" | awk -F ":" '{print $1}')
    # print only usage part
    tail -n +"$usage_start" "$0" | sed -ne '/^#/!q;/^##/q;s/.\{1,2\}//;p'
    exit
}

# print help text given above in comments
function help()
{
    # find usage line
    help_start="`grep -n "^##" "$0" | head -n 1 | awk -F ":" '{print $1}'`"
    # print only usage part
    tail -n +"$help_start" "$0" | sed -ne '/^#/!q;s/.\{1,2\}//;1d;p'
    exit
}

# exit with errorcode 1 & print usage
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

# collect logfiles produced by fuzzer (overwrite by default)
function copy_logs()
{
    verbose_print "Collecting logfiles..."
    [[ -d $LOG_DIR ]] && rm -rf $LOG_DIR/* || mkdir $LOG_DIR
    cp $WORKDIR/*.log $LOG_DIR
    verbose_print "Log files saved to $(realpath $LOG_DIR)"
}

# copy findings from kafl workdir to logs/findings
function copy_findings()
{
    verbose_print "Collecting findings..."
    [[ -d $LOG_DIR ]] || mkdir $LOG_DIR

    num_findings=$(find $WORKDIR/logs -name "*.log" | wc -l)
    if [[ $num_findings -gt 0 ]] 
    then
        findings_dir="$LOG_DIR/findings"
        [[ -d $findings_dir ]] || mkdir $findings_dir
        cp $WORKDIR/logs/*.log $findings_dir
        verbose_print "Findings saved to $(realpath $findings_dir)"
    else
        verbose_print "No findings to copy from $WORKDIR"
    fi
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
        '-l')
            [[ -z "$2" ]] && fatal "Missing parameter LOGDIR"
            LOG_DIR="$2"
        	shift   # past argument
            shift   # past value
            ;;
        '-w')
            [[ -z "$2" ]] && fatal "Missing parameter WORKDIR"
            WORKDIR="$2"
        	shift   # past argument
            shift   # past value
            ;;
        '-f')
            COPY_FINDINGS=1
        	shift   # past argument
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
            shift   # past argument
            ;;
    esac
done
set -- "${POSITIONAL_ARGS[@]}"  # restore positional parameters


[[ -z $WORKDIR ]] && fatal "invalid path to kAFL working directory"
[[ -z $LOG_DIR ]] && fatal "invalid path to log directory"

copy_logs

[[ $COPY_FINDINGS -eq 1 ]] && copy_findings
    
exit 0