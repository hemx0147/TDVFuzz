#!/bin/env bash

##
# Wrapper for fuzz.sh to fixate the command with which the fuzzer is started.
# This script must be run from within kAFL environment.
#
# Usage: start_fuzzer.sh [OPTION]
#
# Options:
#   -h, --help    Display this help text
#   -r RANGE      The IntelPT code range in hexadecimal format
#                 (default: 0x00fffcc2d4-0x00fffddf92)
#   -t            Quick fuzzer test run
#   -c            Run coverage session
##


####################################
# Global Variables
####################################
IPT_RANGE="0x00fffcc2d4-0x00fffddf92"
FUZZER="$BKC_ROOT/fuzz.sh"
RUN_OPTION=0


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

# fuzzer test run
function testrun() {
    timeout -s SIGINT 10s $FUZZER run "$LINUX_GUEST" -t 2 -ts 1 -p 1 --log-hprintf --log --debug -ip0 "$IPT_RANGE"
}

# regular fuzzer
function fuzz() {
    $FUZZER run "$LINUX_GUEST" -t 2 -ts 1 -p 15 --log-crashes -ip0 "$IPT_RANGE"
}

# coverage fuzzer picking up on previous work
function cov() {
    $FUZZER cov "$LINUX_GUEST" -t 2 -p 1 -ip0 "$IPT_RANGE"
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
        '-t')
            RUN_OPTION=1
        	shift   # past argument
            ;;
        '-c')
            RUN_OPTION=2
        	shift   # past argument
            ;;
        '-r')
            [[ -z "$2" ]] && fatal "Missing parameter RANGE"
            IPT_RANGE="$2"
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


# ensure that IntelPT addresses have hexadecimal address format
ipt_start=$(echo $IPT_RANGE | sed 's/-.*//')
ipt_end=$(echo $IPT_RANGE | sed 's/.*-//')
re_addr="^0x[0-9a-fA-F]{1,16}$"
[[ $ipt_start =~ $re_addr ]] || fatal "Bad format of IntelPT range start $ipt_start."
[[ $ipt_end =~ $re_addr ]] || fatal "Bad format of IntelPT range end $ipt_start."

# run fuzzer in specified mode
case "$RUN_OPTION" in
    0) fuzz ;;
    1) testrun ;;
    2) cov ;;
    *) fatal "Unknown run option $RUN_OPTION"
esac