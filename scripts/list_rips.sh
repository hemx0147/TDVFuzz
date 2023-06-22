#!/bin/env bash

##
# List unique instruction pointers (RIPs) and number of their occurance for a given exception type in kAFL log files (crash/kasan/timeout).
#
# If no ECEPTION_NO is provided, then unique RIPs for all occuring exception types are listed.
#
# Usage: list_rips.sh [OPTION] [EXCEPTION_NO]
#
# Options:
#   -h, --help    display this help text
#   -d DIR        Path to directory containing the log files (default: KAFL_WORKDIR/logs)
#   -f            Show log files as well
#
# Parameters:
#   EXCEPTION_NO    Hexdigits of exception vector number according to https://wiki.osdev.org/Exceptions
#                   (e.g. 06 for Invalid Opcode, 0E for Page Fault, etc.)
##
# Note: in some cases the exception data stored in crash log is not correctly formatted. This script may not work correctly in this case.
##


####################################
# Global Variables
####################################
SHOW_FILES=0
LOG_DIR=$(realpath "$KAFL_WORKDIR/logs")
EXNUM="0"

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


####################################
# Main()
####################################

POSITIONAL_ARGS=()
while [[ "$#" -gt 0 ]]
do
  case "$1" in
    '-h'|'--help')
      help
      ;;
    '-d')
      [[ -z "$2" ]] && fatal "Missing parameter DIR"
      LOG_DIR=$(realpath "$2")
      shift   # past argument
      shift   # past value
      ;;
    '-f')
      SHOW_FILES=1
      shift   # past argument
      ;;
    -*|--*)
      fatal "Unknown option $1"
      ;;
    *)
      [[ -z "$1" ]] && fatal "Missing parameter EXCEPTION_NO"
      EXNUM="$1"
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift   # past argument
      ;;
  esac
done
set -- "${POSITIONAL_ARGS[@]}"  # restore positional parameters


[[ -d "$LOG_DIR" ]] || fatal "invalid path to build directory \"$LOG_DIR\""

if [[ $SHOW_FILES -eq 1 ]]
then
  # grep exception type in logs and print file paths
  # grep only RIP line
  # print RIP and file paths only
  # result cleanup: remove ","
  # show only unique results (sort + unique) and print their number of occurence as well
  # replace leading spaces
  # replace leading zeroes by "0x" (do this last so sort works as intended)
  grep -HA2 "Exception Type - $EXNUM" $LOG_DIR/*.log | grep RIP | sed 's/-RIP//' | awk '{print $1" "$3}' | tr -d ',' | sort -k2 | uniq -c | sed 's/^\ \+//' | sed 's/ 0\+/ 0x/'
else
  # grep exception type in logs
  # grep only RIP line
  # print RIP only
  # result cleanup: remove ","
  # show only unique results (sort + unique) and print their number of occurence as well
  # replace leading spaces
  # replace leading zeroes by "0x" (do this last so sort works as intended)
  grep -A2 "Exception Type - $EXNUM" $LOG_DIR/*.log | grep RIP | awk '{print $3}' | tr -d ',' | sort | uniq -c | sed 's/^\ \+//' | sed 's/ 0\+/ 0x/'
fi