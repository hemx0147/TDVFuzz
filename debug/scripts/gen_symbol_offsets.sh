#!/bin/bash

BASE_DIR="/home/ryannick/qemu-test"
LOG="$BASE_DIR/OVMF/debug.log"
BUILD="$BASE_DIR/OVMF/edk2/Build/OvmfX64/DEBUG_GCC5/X64"
PEINFO="$BASE_DIR/peinfo/peinfo"

cat ${LOG} | grep Loading | grep -i efi | while read LINE; do
  BASE="`echo ${LINE} | cut -d " " -f4`"
  NAME="`echo ${LINE} | cut -d " " -f6 | tr -d "[:cntrl:]"`"
  FILE="`find ${BUILD} -name ${NAME} | grep -v OUTPUT \
  		| awk '{print length(), $0 | "sort -n"}' | awk '{print $2}' \
		| head -n 1`"
  ADDR="`${PEINFO} ${FILE} | grep -A 5 text | grep VirtualAddress \
  		| cut -d " " -f2`"
  TEXT="`python -c "print(hex(${BASE} + ${ADDR}))"`"
  SYMS="`echo ${FILE} | sed -e "s/\.efi/\.debug/g"`"
  echo "add-symbol-file ${SYMS} ${TEXT}"
done
