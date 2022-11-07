#!/bin/env bash

##
# Enumerate occurences of TDVF I/O functions.
# This includes Read/Write functions for MMIO, PIO, VirtIO, CR & MSR.
#
# Usage: find_io_functions.sh [OPTION] [SEARCHDIR]
#
# Options:
#   -h, --help    Display this help text
#   -v            Print verbose output
#   -i            Search case-insensitive
#
# Parameters:
#   SEARCHDIR    The directory where the search should be conducted
#                (default: TDVF_ROOT)
##
# The output of this script can be used as input for the populate_queries.py
# script to automatically create a codeql query pack with the found functions.
# 
# This script uses the find_functions.sh script & requires it to exist in
# the same directory.
##


####################################
# Global Variables
####################################
VERBOSE=0
CASE_INSENSITIVE=0
SEARCH_DIR="$TDVF_ROOT"
FIND_FN_SCRIPT="./find_functions.sh"
OUTPUT=

####################################
# Function Definitions
####################################

# print help text given above in comments
function help()
{
	# find help-start line (indicated by two '#')
    help_start="`grep -n "^##" "$0" | head -n 1 | awk -F ":" '{print $1}'`"
    # print only help part
    tail -n +"$help_start" "$0" | sed -ne '/^#/!q;s/.\{0,2\}//;1d;p'
    exit
}

# print script usage information given above in comments
function usage()
{
	# find usage line
    usage_start=$(grep -n "^# Usage" "$0" | awk -F ":" '{print $1}')
    # print only usage part
    tail -n +"$usage_start" "$0" | sed -ne '/^#/!q;/^##/q;s/.\{0,2\}//;p'
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
    [[ $VERBOSE -eq 1 ]] && echo "$1"
}

find_function()
{
    pattern="$1"
    if [[ "$CASE_INSENSITIVE" -eq 1 ]]
    then
        OUTPUT=$($FIND_FN_SCRIPT "-i" "$pattern" "$SEARCH_DIR")
    else
        OUTPUT=$($FIND_FN_SCRIPT "$pattern" "$SEARCH_DIR")
    fi
}

print_output()
{
    if [[ -n "$OUTPUT" ]]
    then
        verbose_print "### $name ###"
        echo "$OUTPUT"
        # print newline for better readability
        verbose_print ""
    fi
}

# example functions
find_mmio() {
    f_type="mmio"
    f_action="(read|write)"
    pattern="^${f_type}${f_action}[0-9]{0,2} ?\("
    find_function "$pattern"
    print_output "MMIO"
}

find_pio() {
    f_type="pio"
    f_action="(read|write)"
    pattern="^${f_type}${f_action}[0-9]{0,2} ?\("
    find_function "$pattern"
    print_output "PIO"
}

find_virtio_pci() {
    f_type="virtiopciio"
    f_action="(read|write)"
    pattern="^${f_type}${f_action}[0-9]{0,2} ?\("
    find_function "$pattern"
    print_output "VirtIO"
}

find_virtio_mmio() {
    f_type="virtiommio"
    f_action="(read|write)"
    pattern="^${f_type}.*${f_action}[0-9]{0,2} ?\("
    find_function "$pattern"
    print_output "VirtIO"
}

find_cr() {
    f_prefix="asm"
    f_type="cr"
    f_action="(read|write)"
    pattern="^${f_prefix}${f_action}${f_type}[0-9]{0,2} ?\("
    find_function "$pattern"
    print_output "CR"
}

find_msr() {
    f_prefix="asm"
    f_type="msr"
    f_action="(read|write)"
    pattern="^${f_prefix}${f_action}${f_type}[0-9]{0,2} ?\("
    find_function "$pattern"
    print_output "MSR"
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
        '-v')
            VERBOSE=1
            shift   # past argument
            ;;
        '-i')
            CASE_INSENSITIVE=1
            shift   # past argument
            ;;
        -*|--*)
        	fatal "Unknown option $1"
            ;;
        *)
            POSITIONAL_ARGS+=("$1") # save positional arg
            SEARCH_DIR="$1"
            shift   # past argument
            ;;
    esac
done
set -- "${POSITIONAL_ARGS[@]}"  # restore positional parameters


[[ -d "$SEARCH_DIR" ]] || fatal "invalid path to SEARCHDIR \"$SEARCH_DIR\""
[[ -f "$FIND_FN_SCRIPT" ]] || fatal "find_functions script \"$FIND_FN_SCRIPT\" not found"

# find functions
find_mmio
find_pio
find_virtio_pci
find_virtio_mmio
find_cr
find_msr

exit 0