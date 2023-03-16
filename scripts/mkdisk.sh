#!/bin/env bash

# create a UEFI-bootable disk image
# args:
#   path to hello world app
# 
# Note: for the mounting/unmounting to work, these commands must be executed as root.
# Since it's usually a bad idea to run individual commands within script as root, the
# entire script should be ran as root but commands that do not require root will be
# called with `sudo -u $username`.

IMG="image.img"
MNT="./sharedir"
BOOT_PATH="$MNT/EFI/BOOT"
BOOTX64="$BOOT_PATH/BOOTX64.EFI"
APP="tdvfuzz/tdvf/Build/MdeModule/DEBUG_GCC5/X64/HelloWorld.efi"

set -e


# abort if script is run without root privileges
if ! [[ $(id -u) = 0 ]]
then
  echo "The script need to be run as root." >&2
  exit 1
fi

if [ $SUDO_USER ]
then
  USR=$SUDO_USER
else
  USR=$(whoami)
fi
 
# obtain APP path per command line param if given
[[ $# -gt 0 ]] && APP="$1"

# verify that APP path exists
APP="/home/$USR/$APP"
if ! [[ -f $APP ]]
then
  echo "error: invalid app path $APP" >&2
  exit 1
fi


# create qemu image
sudo -u $USR qemu-img create $IMG 120M

# create GPT & make ESP from image
# -Z  destroy GPT & MBR structures
# -g  convert MBR to GPT (create new GPT)
# -n  add new partition number 1, rest is default
# -t  change type of partition 1 to EFI System Partion
# -c  change name of partition 1
sudo -u $USR sgdisk -Z -g -n 1:: -t 1:ef00 -c 1:"EFI system partition" $IMG

# create FAT32 file system on image
sudo -u $USR mkfs.fat -F 32 $IMG


#! sudo privileges needed from here!

# mount image
sudo mount $IMG $MNT

# create well-known boot path
sudo mkdir -p $BOOT_PATH

# copy HelloWorld.efi to boot path
sudo cp $APP $BOOTX64

# unmount image
sudo umount $MNT
