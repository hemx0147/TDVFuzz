#!/bin/bash

##
# Generate a mapping of loaded EDK modules to their corresponding memory offset
# in a qemu session.
# The output can be executed as a script in GDB such that GDB automatically
# imports the symbols of all modules loaded in the qemu session.
#
# Requirements:
#   - OVMF log file containing debug prints with addresses of loaded modules (debug.log)
#   - OVMF debug build files from build with DEBUG flag
#   - peinfo tool: https://github.com/retrage/peinfo
##

# TODO: add secmain debug info

BASE_DIR="/home/ryannick/tdvfuzz"
LOG="$BASE_DIR/debug/debug.log"
BUILD_DIR="$BASE_DIR/targets/edk2/Build"
SEARCH_DIR="$BUILD_DIR/OvmfX64/DEBUG_GCC5/X64"
PEINFO="$BASE_DIR/tools/peinfo/peinfo"

# SecMain is not part of debug log
MAP="${BUILD_DIR}/OvmfX64/DEBUG_GCC5/Ovmf.map"
MEM_BASE="`grep SecMain.*BaseAddress ${MAP} | awk -F ',' '{print $2}' | grep -oE '0x[a-fA-F0-9]{1,16}'`"
ADDR="`${PEINFO} ${SECMAIN} | grep -A 5 text | grep VirtualAddress | cut -d ' ' -f2`"
TEXT="`python -c "print(hex(${MEM_BASE} + ${ADDR}))"`"
SYMFILE="${SEARCH_DIR}/OvmfPkg/Sec/SecMain/DEBUG/SecMain.debug"
echo "add-symbol-file ${SYMFILE} ${TEXT}"

# find memory addresses for other modules
cat ${LOG} | grep Loading | grep -i efi | while read LINE; do
  MEM_BASE="`echo ${LINE} | cut -d " " -f4`"
  FILE_NAME="`echo ${LINE} | cut -d " " -f6 | tr -d "[:cntrl:]"`"
  FILE_BASENAME=$(echo ${FILE_NAME} | sed -e "s/.efi$//")
#   echo ${LINE}
#   echo ${MEM_BASE}
#   echo ${FILE_NAME}
#   echo ${FILE_BASENAME}
  EFIFILE="`find ${SEARCH_DIR} -name ${FILE_NAME} -maxdepth 1 -type f`"
  if [[ -z ${EFIFILE} ]]
  then
	# some .efi files exist in nested directories only
	EFIFILE="`find ${SEARCH_DIR} -name ${FILE_NAME} -type f | grep ${FILE_BASENAME}/DEBUG/${FILE_NAME}`"
  fi
  ADDR="`${PEINFO} ${EFIFILE} | grep -A 5 text | grep VirtualAddress | cut -d ' ' -f2`"
#   echo ${EFIFILE}
#   echo ${ADDR}
  TEXT="`python -c "print(hex(${MEM_BASE} + ${ADDR}))"`"
#   echo ${TEXT}
  SYMS="`echo ${FILE_NAME} | sed -e "s/\.efi/\.debug/g"`"
#   echo ${SYMS}
  SYMFILE="`find ${SEARCH_DIR} -name ${SYMS} -type f -maxdepth 1`"
  if [[ -z ${SYMFILE} ]]
  then
	# some .debug files exist in nested directories only
	SYMFILE="`find ${SEARCH_DIR} -name ${SYMS} -type f | grep ${FILE_BASENAME}/DEBUG/${SYMS}`"
  fi
#   echo ${SYMFILE}
  echo "add-symbol-file ${SYMFILE} ${TEXT}"
done