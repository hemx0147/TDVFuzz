#!/bin/bash

# Fix the qemu startup command


BASE_DIR=/home/ryannick/qemu-test

# qemu vars
QEMU_SYS=/usr/bin/qemu-system-x86_64
QEMU_KAFL=~/tdx/kafl/qemu/x86_64-softmmu/qemu-system-x86_64
IMG=$BASE_DIR/image.img
HDA=$BASE_DIR/fat-dir
MEM=2G
SERIAL_LOG=$BASE_DIR/serial.log
LOG=$BASE_DIR/debug.log
ISO=$BASE_DIR/ubuntu-22.04.1-live-server-amd64.iso

# OVMF vars (note: for some reason OVMF.fd is in different dir than OVMF_XXXX.fd)
# OVMF_DIR=/usr/share/OVMF
# OVMF_BIN=/usr/share/ovmf/OVMF.fd
# OVMF_CODE=$OVMF_DIR/OVMF_CODE.fd
# OVMF_VARS=$OVMF_DIR/OVMF_VARS.fd
OVMF_DIR=$BASE_DIR/edk2/Build/OvmfX64/DEBUG_GCC5/FV
OVMF_BIN=$OVMF_DIR/OVMF.fd
OVMF_CODE=$OVMF_DIR/OVMF_CODE.fd
OVMF_VARS=$OVMF_DIR/OVMF_VARS.fd

# TDVF vars
TDVF_DIR=~/tdx/kafl/edk.git/Build/OvmfX64/DEBUG_GCC5/FV
TDVF_BIN=$TDVF_DIR/OVMF.fd
TDVF_CODE=$TDVF_DIR/OVMF_CODE.fd
TDVF_VARS=$TDVF_DIR/OVMF_VARS.fd


# write serial out to log file
# -chardev stdio,mux=on,id=char0,logfile=qemu_file.txt,signal=off \
# -mon chardev=char0 \
# -serial chardev:char0 \

    # -hdc fat:rw:$HDA \
    # -drive file=$IMG,if=virtio,format=qcow2,unit=1,media=disk \

$QEMU_SYS -nographic \
    -enable-kvm \
    -cpu host \
    -net none \
    -m $MEM \
    -drive if=pflash,format=raw,readonly,file=$OVMF_BIN \
    -drive if=virtio,format=raw,file=fat:rw:$HDA