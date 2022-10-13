#!/bin/bash

# This script builds sets up EDK2 environment (if necessary), builds custom TDVF, creates symlink & starts the fuzzer.
# This script must be run from within the kAFL environment.


########## FUNCTION DEFINITIONS ##########

# print help / script usage
function usage()
{
    cat << HERE

Usage: $0 <cmd> <dir> [args]

Available commands <cmd>:
  test    <target> [args] - test bla

  TODO: extend this help text
HERE
    exit
}

# set up EDK environment
function edk_setup()
{
    echo "Setting up EDK environment..."
    make -C BaseTools clean
    make -C BaseTools
    export EDK_TOOLS_PATH=$PWD/BaseTools
    source edksetup.sh
}

# collect logfiles produced by fuzzer
function collect_logs()
{
    [[ -f $SCRIPTS/collect_logs.sh ]] || fatal "Could not find copy-logs script in $SCRIPTS."
    $SCRIPTS/collect_logs.sh
}

# exit with errorcode 1 & print usage
function fatal()
{
    echo $1
    usage
    exit 1
}


########## MAIN CODE ##########

WORKDIR=~/tdvf-hello
SCRIPTS=$WORKDIR/scripts
[[ -d $WORKDIR ]] || fatal "Could not find WORKDIR. Verify that working directory exists."
[[ -d $SCRIPTS ]] || fatal "Could not find SCRIPTS. Verify that script directory exists."

# test if in KAFL environment
[[ -z "$BKC_ROOT" ]] && fatal "Could not find BKC_ROOT. Verify that kAFL environment is set up."
[[ -z "$KAFL_ROOT" ]] && fatal "Could not find KAFL_ROOT. Verify that kAFL environment is set up."

# set variables based on kafl environment
EDK_DIR=$BKC_ROOT/kafl/edk.git
BUILD_DIR=$EDK_DIR/Build/OvmfX64/DEBUG_GCC5
TDVF_DSC=$EDK_DIR/OvmfPkg/OvmfPkgX64.dsc
TDVF_BIN=$BUILD_DIR/FV/OVMF.fd
SEC_MAP=$BUILD_DIR/FV/SECFV.Fv.map
TDVF_IMG_NAME=TDVF_hello.fd


# set up EDK environment if necessary
pushd $EDK_DIR > /dev/null
NUM_BUILT_FILES=$(find BaseTools -type f -name "*.pyc" -or -name "*.o" | wc -l)
[[ $NUM_BUILT_FILES -eq 0 || -z "$WORKSPACE" || -z "$EDK_TOOLS_PATH" || -z "$CONF_PATH" ]] && edk_setup || echo "EDK environment already set up."


# build TDVF (overwrites existing files by default)
echo "Building TDVF..."
build -n $(nproc) -p OvmfPkg/OvmfPkgX64.dsc -t GCC5 -a X64 -D TDX_EMULATION_ENABLE=FALSE -D DEBUG_ON_SERIAL_PORT=TRUE
[[ -f $TDVF_BIN ]] || fatal "Could not find TDVF binary in $BUILD_DIR/FV. Consider rebuilding TDVF."
[[ -f $SEC_MAP ]] || fatal "Could not find TDVF binary in $BUILD_DIR/FV. Consider rebuilding TDVF."
popd > /dev/null


# copy TDVF image & create symlink
echo "Creating TDVF symlink in $BKC_ROOT..."
cp $TDVF_BIN $BKC_ROOT/$TDVF_IMG_NAME
ln -fs $BKC_ROOT/$TDVF_IMG_NAME $BKC_ROOT/TDVF.fd


# find start of IPT code range from SEC linker map (range end is just a guess for now)
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
timeout -s SIGINT 10s ./fuzz.sh run linux-guest -t 2 -ts 1 -p 1 --log-hprintf --log --debug -ip0 $IPT_RANGE
popd > /dev/null

# collect logfiles produced by fuzzer
collect_logs

echo "done."
exit 0