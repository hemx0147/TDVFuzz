#!/bin/env bash

##
# Print the memory range of the TDVF SecMain module .text section.
#
# Usage: get_sec_range.sh [OPTION] [BUILDDIR]
#
# Options:
#   -h, --help    display this help text
#   -v            print verbose output
#
# Parameters:
#   BUILDDIR    Path to the EDK2/TDVF Build directory (default: TDVF_ROOT/Build)
##
# The information is acquired from TDVF debug build files.
##


####################################
# Global Variables
####################################
TDVF_BUILD_DIR="$TDVF_ROOT/Build"
ADDR_LEN=10
VERBOSE=0

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

# exit with errorcode 1 & print usage
function fatal()
{
    [[ -n "$1" ]] && echo "Error: $1"; echo
    usage >&2
    exit 1
}

# print addresses for image base, .text & .data
function print_addresses()
{
    printf "Module SecMain\n"
    printf -- "-%.0s" {1..25}
    printf "\n"
    printf "image base   0x%.10x\n" "$IMG_START"
    printf ".text start  0x%.10x\n" "$TXT_START"
    printf ".text end    0x%.10x\n" "$TXT_END"
    printf ".text size   0x%.10x\n" "$TXT_SIZE"
    printf ".data start  0x%.10x\n\n" "$DAT_START"
}



####################################
# Main()
####################################

# argument parsing
# note: options can be given multiple times,
#       i.e. "script -n 5 -n 10" executes func_with_args once with 5 and once with 10
POSITIONAL_ARGS=()
while [[ "$#" -gt 0 ]]
do
	case "$1" in
        '-h'|'--help')
            help
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
            TDVF_BUILD_DIR="$1"
            shift   # past argument
            ;;
    esac
done
set -- "${POSITIONAL_ARGS[@]}"  # restore positional parameters

# check whether build dir was specified
[[ -n $TDVF_BUILD_DIR || -d $TDVF_BUILD_DIR ]] || fatal "invalid path to TDVF Build directory"

# 1. get .text start from SEC map file
SEC_MAP="`find $TDVF_BUILD_DIR -type f -name 'SECFV.Fv.map'`"
IMG_START="`grep -oE '.BaseAddress=0x[0-9a-fA-F]{1,16}' $SEC_MAP | awk -F '=' '{print $2}'`"
TXT_START="`grep -oE '.textbaseaddress=0x[0-9a-fA-F]{1,16}' $SEC_MAP | awk -F '=' '{print $2}'`"
DAT_START="`grep -oE '.databaseaddress=0x[0-9a-fA-F]{1,16}' $SEC_MAP | awk -F '=' '{print $2}'`"

# 2. get .text size from SecMain debug file
SEC_DEBUG="`find $TDVF_BUILD_DIR -type f -name 'SecMain.debug' | head -n 1`"
TXT_SIZE="0x`readelf -SW $SEC_DEBUG | grep -w '.text ' | awk '{print $7}'`"
TXT_END="$(($TXT_START + $TXT_SIZE))"

# 3. (optional) print verbose output 
[[ $VERBOSE -eq 1 ]] && print_addresses

# 4. print code range
printf "0x%.10x-0x%.10x\n" "$TXT_START" "$TXT_END"