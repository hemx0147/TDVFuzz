#!/bin/env bash

# TODO: add verbose option
# TODO: add rebuild tdvf option
# TODO: linux boot fuzzing setup is only required because fuzz.sh was not yet updated -> update fuzz.sh

##
# This script performs the following actions:
#   - set up EDK2 environment in TDVF_ROOT
#   - build custom TDVF (requires edksetup environment)
#   - create TDVF symlink in BKC_ROOT
#   - start fuzzer for a few seconds (requires kafl environment)
#
# Requires complete Linux Boot Fuzzing setup as specified here:
# https://github.com/hemx0147/TDVFuzz/tree/master/workdir/bkc/kafl#linux-boot-fuzzing
#
#
# Usage: build-n-fuzz.sh [OPTION]
#
# Options:
#   -h, --help    Display this help text
#   -e EDKDIR     The EDK2 repository (default: TDVF_ROOT)
#   -b            Rebuild TDVF
#   -c            Copy log files from KAFL_WORKDIR to current working directory
##
# Log files include hprintf-, serial- & debug logs and will be copied to a
# directory "logs" in the current working directory.
##


####################################
# Global Variables
####################################

COLLECT_LOGS=0
REBUILD_TDVF=0
EDK_DIR="$TDVF_ROOT"
TDVF_DSC="$EDK_DIR/OvmfPkg/OvmfPkgX64.dsc"
BUILD_DIR="$EDK_DIR/Build/OvmfX64/DEBUG_GCC5/FV"
TDVF_BIN="$BUILD_DIR/OVMF.fd"
SEC_MAP="$BUILD_DIR/SECFV.Fv.map"
TDVF_IMG_NAME="TDVF_hello.fd"
TDVF_LINK_NAME="TDVF.fd"
LOG_DIR="logs"
SEC_RANGE_SCRIPT="./get_sec_range.sh"
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

# set up EDK build environment (env will be active only for this script instance)
function edk_setup()
{
    pushd $EDK_DIR > /dev/null
    num_build_files=$(find BaseTools -type f -name "*.pyc" -or -name "*.o" | wc -l)
    if [[ $num_build_files -eq 0 ]]
    then
    	echo "Building BaseTools..."
        make -C BaseTools
    fi

    if [[ -z "$WORKSPACE" || -z "$EDK_TOOLS_PATH" || -z "$CONF_PATH" ]]
    then
        echo "Setting up EDK build environment..."
        source edksetup.sh --reconfig
    else
        echo "EDK environment already set up."
    fi
    popd > /dev/null
}

# collect logfiles produced by fuzzer (overwrite by default)
function copy_logs()
{
    logdir="$1"
    echo "Collecting logfiles..."
    [[ -d $logdir ]] && rm -rf $logdir/* || mkdir $logdir
    cp $KAFL_WORKDIR/*.log $logdir
}

# build TDVF (overwrites existing files by default)
function build_and_link_tdvf()
{
    echo "Building TDVF..."

    # rebuild TDVF
    pushd $EDK_DIR > /dev/null
    build -n $(nproc) -p OvmfPkg/OvmfPkgX64.dsc -t GCC5 -a X64 -D TDX_EMULATION_ENABLE=FALSE -D DEBUG_ON_SERIAL_PORT=TRUE
    [[ -f $TDVF_BIN ]] || fatal "Could not find TDVF binary in $BUILD_DIR. Consider rebuilding TDVF."
    [[ -f $SEC_MAP ]] || fatal "Could not find TDVF binary in $BUILD_DIR. Consider rebuilding TDVF."
    popd > /dev/null

    # copy TDVF image & create symlink
    echo "Creating TDVF symlink in $BKC_ROOT..."
    cp $TDVF_BIN $BKC_ROOT/$TDVF_IMG_NAME
    ln -fs $BKC_ROOT/$TDVF_IMG_NAME $BKC_ROOT/$TDVF_LINK_NAME
}

# get Intel PT code range for SecMain module
function get_ipt_range()
{
    echo "Obtaining Intel PT code range..."
    if [[ -f "$SEC_RANGE_SCRIPT" ]]
    then
        # call SEC range script since it exists in CWD
        IPT_RANGE=$($SEC_RANGE_SCRIPT)
        ipt_start=$(echo $IPT_RANGE | sed 's/-.*//')
        ipt_end=$(echo $IPT_RANGE | sed 's/.*-//')
    else
        # use default values
        ipt_start=$(grep SecMain $SEC_MAP | sed 's/.*BaseAddress=\(0x[0-9a-fA-F]\{10\}\).*/\1/')
        ipt_end=0x00ffffffff
        IPT_RANGE=$ipt_start-$ipt_end
    fi

    # ensure that found IPT addresses match 64-bit hexadecimal address format
    re_addr="^0x[0-9a-fA-F]{1,16}$"
    [[ $ipt_start =~ $re_addr ]] || fatal "Bad format of IPT range start $ipt_start. Check $SEC_MAP for potential issues."
    [[ $ipt_end =~ $re_addr ]] || fatal "Bad format of IPT range end $ipt_start. Check $SEC_MAP for potential issues."

    echo "Using Intel PT code range $IPT_RANGE"
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
        '-c')
            COLLECT_LOGS=1
        	shift   # past argument
            ;;
        '-b')
            REBUILD_TDVF=1
        	shift   # past argument
            ;;
        '-e')
            [[ -z "$2" ]] && fatal "Missing parameter EDKDIR"
            EDK_DIR="$2"
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
[[ -z "$TDVF_ROOT" ]] && fatal "Could not find TDVF_ROOT. Verify that kAFL environment is set up."

# set up EDK environment if necessary
edk_setup

# rebuild TDVF if necessary
[[ $REBUILD_TDVF -eq 1 ]] && build_and_link_tdvf

# get Intel PT code range
get_ipt_range

# start fuzzer with 1 worker & high verbosity (to detect issues before proper fuzzing session)
echo "Starting fuzzer for a few seconds..."
pushd $BKC_ROOT > /dev/null
timeout -s SIGINT 10s ./fuzz.sh run $LINUX_GUEST -t 2 -ts 1 -p 1 --log-hprintf --log --debug -ip0 $IPT_RANGE
popd > /dev/null


# collect logfiles from KAFL_WORKDIR
[[ $COLLECT_LOGS -eq 1 ]] && copy_logs $LOG_DIR

echo "done."
exit 0