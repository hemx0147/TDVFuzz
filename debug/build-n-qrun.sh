#!/bin/env bash

###
# Rebuild & run TDVF in qemu
# usage: ./bnr.sh [--build|--rebuild]
###


### argline parsing
REBUILD=0
BUILD=0
if [[ "$#" -gt 0 ]]
then
  [[ "$1" = "--build" ]] && BUILD=1
  [[ "$1" = "--rebuild" ]] && REBUILD=1
fi


### rebuild TDVF
TDVF_ROOT=~/tdvfuzz/tdvf
TDVF_BUILD_DIR=$TDVF_ROOT/Build/IntelTdx/DEBUG_GCC5/FV
TDVF_CODE=$TDVF_BUILD_DIR/OVMF_CODE.fd
TDVF_VARS=$TDVF_BUILD_DIR/OVMF_VARS.fd

if [[ "$BUILD" -eq 1 || "$REBUILD" -eq 1 ]]
then
  pushd $TDVF_ROOT > /dev/null
  [[ "$REBUILD" -eq 1 ]] && (echo "deleting build dir" ; rm -rf Build)
  [[ -z "$WORKSPACE" || -z "$EDK_TOOLS_PATH" || -z "$CONF_PATH" ]] && source edksetup.sh
  echo "building tdvf"
  build -n $(nproc) -p OvmfPkg/IntelTdx/IntelTdxX64.dsc -t GCC5 -a X64 -D TDX_EMULATION_ENABLE=FALSE -D DEBUG_ON_SERIAL_PORT=TRUE
  popd > /dev/null
fi


### run TDVF in qemu
MEM="1G"
LOG="debug.log"

QEMU=~/tdvfuzz/kafl/qemu/x86_64-softmmu/qemu-system-x86_64
QEMU_FLAGS="-m $MEM -nographic \
	-enable-kvm \
	-machine kAFL64-v1 \
	-cpu kAFL64-Hypervisor-v1,+vmx \
	-drive if=pflash,format=raw,readonly,file=$TDVF_CODE \
	-drive if=pflash,format=raw,file=$TDVF_VARS \
  -serial stdio \
	-nodefaults"

# use timeout to stop qemu execution immediately when reaching UEFI shell
timeout --foreground -s SIGINT 5s $QEMU $QEMU_FLAGS | tee "$LOG"