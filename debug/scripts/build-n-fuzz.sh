#!/bin/env bash

# TODO: add verbose option
# TODO: add rebuild tdvf option

##
# This script performs the following actions:
#   - set up EDK2 environment in TDVF_ROOT
#   - build custom TDVF (requires edksetup environment)
#   - create TDVF symlink in BKC_ROOT
#   - start fuzzer for a few seconds (requires kafl environment)
#
# Requires complete Linux Boot Fuzzing setup as specified here:
# https://github.com/hemx0147/ccc-linux-guest-hardening/tree/master/tdx/bkc/kafl#linux-boot-fuzzing
#
#
# Usage: build-n-fuzz.sh [OPTION]
#
# Options:
#   -h, --help    Display this help text
#   -e EDKDIR     The EDK2 repository (default: TDVF_ROOT)
#   -c            Copy log files from KAFL_WORKDIR to current working directory
#
# Log files include hprintf-, serial- & debug logs and will be copied to a
# directory "logs" in the current working directory.
##


####################################
# Global Variables
####################################

COLLECT_LOGS=0
EDK_DIR="$TDVF_ROOT"
TDVF_DSC="$EDK_DIR/OvmfPkg/OvmfPkgX64.dsc"
BUILD_DIR="$EDK_DIR/Build/OvmfX64/DEBUG_GCC5/FV"
TDVF_BIN="$BUILD_DIR/OVMF.fd"
SEC_MAP="$BUILD_DIR/SECFV.Fv.map"
TDVF_IMG_NAME="TDVF_hello.fd"
TDVF_LINK_NAME="TDVF.fd"
LOG_DIR="logs"

####################################
# Function Definitions
####################################

# print help / script usage given above in comments
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

# set up EDK build environment
function edk_setup()
{
    echo "Setting up EDK build environment..."
    make -C BaseTools
    source edksetup.sh --reconfig
}

# collect logfiles produced by fuzzer (overwrite by default)
function copy_logs()
{
    logdir="$1"
    echo "Collecting logfiles..."
    [[ -d $logdir ]] && rm -rf $logdir/* || mkdir $logdir
    cp $KAFL_WORKDIR/*.log $logdir
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
            usage
            ;;
        '-c')
            COLLECT_LOGS=1
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
            echo "$1"
            shift   # past argument
            ;;
    esac
done
set -- "${POSITIONAL_ARGS[@]}"  # restore positional parameters

# test if in KAFL environment
# TODO: just source kafl env if variables not yet set -> removes requirement of being inside kafl env
[[ -z "$BKC_ROOT" ]] && fatal "Could not find BKC_ROOT. Verify that kAFL environment is set up."
[[ -z "$KAFL_ROOT" ]] && fatal "Could not find KAFL_ROOT. Verify that kAFL environment is set up."
[[ -z "$TDVF_ROOT" ]] && fatal "Could not find TDVF_ROOT. Verify that kAFL environment is set up."


# set up EDK environment if necessary
# TODO: just source edk env if variables not yet set -> removes requirement of being inside edk env
pushd $EDK_DIR > /dev/null
NUM_BUILT_FILES=$(find BaseTools -type f -name "*.pyc" -or -name "*.o" | wc -l)
[[ $NUM_BUILT_FILES -eq 0 || -z "$WORKSPACE" || -z "$EDK_TOOLS_PATH" || -z "$CONF_PATH" ]] && edk_setup || echo "EDK environment already set up."


# build TDVF (overwrites existing files by default)
echo "Building TDVF..."
build -n $(nproc) -p OvmfPkg/OvmfPkgX64.dsc -t GCC5 -a X64 -D TDX_EMULATION_ENABLE=FALSE -D DEBUG_ON_SERIAL_PORT=TRUE
[[ -f $TDVF_BIN ]] || fatal "Could not find TDVF binary in $BUILD_DIR. Consider rebuilding TDVF."
[[ -f $SEC_MAP ]] || fatal "Could not find TDVF binary in $BUILD_DIR. Consider rebuilding TDVF."
popd > /dev/null


# copy TDVF image & create symlink
echo "Creating TDVF symlink in $BKC_ROOT..."
cp $TDVF_BIN $BKC_ROOT/$TDVF_IMG_NAME
ln -fs $BKC_ROOT/$TDVF_IMG_NAME $BKC_ROOT/$TDVF_LINK_NAME


# find start of IPT code range from SEC linker map (range end is just a guess for now)
# TODO: fix memranges for hello-world fuzzing
echo "Obtaining Intel PT code ranges..."
IPT_START=$(grep SecMain $SEC_MAP | sed 's/.*BaseAddress=\(0x[0-9a-f]\{10\}\).*/\1/')
IPT_END=0x00ffffffff
IPT_RANGE=$IPT_START-$IPT_END

# ensure that found IPT addresses match 64-bit hexadecimal address format
RE_ADDR="^0x[0-9a-fA-F]{1,16}$"
[[ $IPT_START =~ $RE_ADDR ]] || fatal "Bad format of start of IPT range $IPT_START. Check $SEC_MAP for potential issues."
[[ $IPT_END =~ $RE_ADDR ]] || fatal "Bad format of end of IPT range $IPT_START. Check $SEC_MAP for potential issues."


# start fuzzer with 1 worker & high verbosity (to detect issues before "real" fuzzing session)
echo "Starting fuzzer for a few seconds..."
pushd $BKC_ROOT > /dev/null
timeout -s SIGINT 10s ./fuzz.sh run $LINUX_GUEST -t 2 -ts 1 -p 1 --log-hprintf --log --debug -ip0 $IPT_RANGE
popd > /dev/null


# collect logfiles from KAFL_WORKDIR
[[ $COLLECT_LOGS -eq 1 ]] && copy_logs $LOG_DIR

echo "done."
exit 0