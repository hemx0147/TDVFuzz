#!/bin/env bash

##
# This script performs the following actions:
#   - set up EDK2 environment in TDVF_ROOT
#   - (re-)build custom TDVF & create TDVF symlink in project root (optional)
#   - start fuzzer for a few seconds (requires kafl environment)
#
# Usage: build-n-fuzz.sh [OPTION]
#
# Options:
#   -h, --help      Display this help text
#   -b              Build TDVF
#   -r              Delete TDVF Build directory and rebuild TDVF from scratch
#   -v              print verbose output
##
# Note: currently this script requires complete Linux Boot Fuzzing setup as specified here:
# https://github.com/hemx0147/TDVFuzz/tree/master/bkc/kafl#linux-boot-fuzzing
##


####################################
# Global Variables
####################################

# stop script execution if any command returns non-zero value (usually error)
set -e

# command line argument flags
BUILD_TDVF=0
REBUILD_TDVF=0
VERBOSE=0

TDVF_DSC="$TDVF_ROOT/OvmfPkg/OvmfPkgX64.dsc"
BUILD_DIR="$TDVF_ROOT/Build/OvmfX64/DEBUG_GCC5/FV"
TDVF_BIN="$BUILD_DIR/OVMF.fd"
SEC_MAP="$BUILD_DIR/SECFV.Fv.map"
SEC_DBG="$BUILD_DIR/../X64/SecMain.debug"
TDVF_IMG_NAME="TDVF_kafl.fd"
TDVF_LINK_NAME="TDVF.fd"
IPT_RANGE=""

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
    echo "input file: '$0'"
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
    [[ $VERBOSE -eq 1 ]] && echo "$1"
}

# set up EDK build environment (env will be active only for this script instance)
function edk_setup()
{
    pushd $TDVF_ROOT > /dev/null
    num_build_files=$(find BaseTools -type f -name "*.pyc" -or -name "*.o" | wc -l)
    if [[ $num_build_files -eq 0 ]]
    then
    	verbose_print "Building BaseTools..."
        make -C BaseTools
    else
        verbose_print "Using EDK BaseTools at $(realpath $TDVF_ROOT/BaseTools)"
    fi

    if [[ -z "$WORKSPACE" || -z "$EDK_TOOLS_PATH" || -z "$CONF_PATH" ]]
    then
        verbose_print "Setting up EDK build environment..."
        [[ $VERBOSE -eq 1 ]] && source edksetup.sh --reconfig || source edksetup.sh --reconfig > /dev/null
    else
        verbose_print "EDK environment already set up."
    fi
    popd > /dev/null
}

# build TDVF (overwrites existing files by default)
function build_and_link_tdvf()
{
    pushd $TDVF_ROOT > /dev/null

    # delete build directory if rebuild flag set
    if [[ $REBUILD_TDVF -eq 1 ]]
    then
        verbose_print "Deleting TDVF Build directory..."
        rm -rf Build > /dev/null
    fi

    verbose_print "Rebuilding TDVF..."
    build -n $(nproc) -p $TDVF_DSC -t GCC5 -a X64 -D TDX_EMULATION_ENABLE=FALSE -D DEBUG_ON_SERIAL_PORT=TRUE
    [[ -f $TDVF_BIN ]] || fatal "Could not find TDVF binary in $BUILD_DIR. Consider rebuilding TDVF."
    [[ -f $SEC_MAP ]] || fatal "Could not find SECMAIN map file in $BUILD_DIR. Consider rebuilding TDVF."
    popd > /dev/null

    # copy TDVF image
    verbose_print "Copying TDVF image..."
    cp $TDVF_BIN $IMAGE_ROOT/$TDVF_IMG_NAME
    verbose_print "TDVF image copied to $(realpath $IMAGE_ROOT)"

    # create TDVF symlink
    verbose_print "Creating TDVF symlink..."
    ln -fs $IMAGE_ROOT/$TDVF_IMG_NAME $BKC_ROOT/$TDVF_LINK_NAME
    verbose_print "Symlink $TDVF_IMG_NAME -> $TDVF_LINK_NAME created"
}

# get Intel PT code range for SecMain module
function get_ipt_range()
{
    verbose_print "Obtaining IntelPT code range for SecMain module..."

    # get SecMain .text start & end from SecMain map & debug file
    txt_size="0x$(readelf -SW $SEC_DBG | grep -w '.text ' | awk '{print $7}')"
    ipt_start="`grep -oE '.textbaseaddress=0x[0-9a-fA-F]{1,16}' $SEC_MAP | awk -F '=' '{print $2}'`"
    ipt_end="$(printf 0x%0.10x $(($ipt_start + $txt_size)))"
    IPT_RANGE=$ipt_start-$ipt_end

    # ensure that found IntelPT addresses match 64-bit hexadecimal address format
    re_addr="^0x[0-9a-fA-F]{1,16}$"
    [[ $ipt_start =~ $re_addr ]] || fatal "Bad format of IntelPT range start $ipt_start. Check $SEC_MAP for potential issues."
    [[ $ipt_end =~ $re_addr ]] || fatal "Bad format of IntelPT range end $ipt_start. Check $SEC_MAP for potential issues."

    verbose_print "Using Intel PT code range $IPT_RANGE"
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
        '-b')
            BUILD_TDVF=1
            shift   # past argument
            ;;
        '-r')
            REBUILD_TDVF=1
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


# test if in KAFL environment
[[ -z "$BKC_ROOT" ]] && fatal "Could not find BKC_ROOT. Verify that kAFL environment is set up."
[[ -z "$KAFL_ROOT" ]] && fatal "Could not find KAFL_ROOT. Verify that kAFL environment is set up."
[[ -z "$TDVF_ROOT" ]] && fatal "Could not find TDVF_ROOT. Verify that kAFL environment is set up."
[[ -z "$IMAGE_ROOT" ]] && fatal "Could not find IMAGE_ROOT. Verify that kAFL environment is set up."

# set up EDK environment if necessary
edk_setup

# rebuild TDVF if necessary
[[ $BUILD_TDVF -eq 1 || $REBUILD_TDVF -eq 1 ]] && build_and_link_tdvf

# get Intel PT code range
get_ipt_range

# start fuzzer with 1 worker & high verbosity (to detect issues before proper fuzzing session)
verbose_print "Running fuzzer for a few seconds..."
pushd $BKC_ROOT > /dev/null
timeout -s SIGINT 10s ./fuzz.sh run $LINUX_GUEST -t 2 -ts 1 -p 1 --log-hprintf --log --debug -ip0 $IPT_RANGE
popd > /dev/null

verbose_print "Done."
exit 0