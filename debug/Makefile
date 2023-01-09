#!/usr/bin/env make


# general 
MEM=1G
LOG=debug.log

# TDVF
TDVF_ROOT = ~/tdvfuzz/tdvf
TDVF_BUILD_DIR = $(TDVF_ROOT)/Build/IntelTdx/DEBUG_GCC5/FV
TDVF_BIN = $(TDVF_BUILD_DIR)/OVMF.fd
TDVF_CODE = $(TDVF_BUILD_DIR)/OVMF_CODE.fd
TDVF_VARS = $(TDVF_BUILD_DIR)/OVMF_VARS.fd


##
# This approach works with OVMF from tianocore edk2 (both with stock & kafl qemu)
##
# QEMU = ~/tdvfuzz/kafl/qemu/x86_64-softmmu/qemu-system-x86_64
# QEMU_FLAGS = -m $(MEM) -nographic \
#	 -enable-kvm \
#	 -machine kAFL64-v1 \
# 	-pflash $(TDVF_BIN) \
# 	-serial stdio \
# 	-nodefaults

##
# kAFL qemu start options
##
# -enable-kvm
# -machine kAFL64-v1
# -cpu kAFL64-Hypervisor-v1,+vmx
# -smp 1
# -no-reboot
# -display none
# -nodefaults
# -netdev user,id=mynet0
# -device virtio-net,netdev=mynet0
# -virtfs local,path=/tmp/kafl,mount_tag=tmp,security_model=mapped-file
# -device virtio-serial
# -device virtconsole,chardev=kafl_serial
# -device isa-serial,chardev=kafl_serial
# -chardev socket,server,id=nyx_socket,path=/dev/shm/default/interface_0
# -device nyx,chardev=nyx_socket,workdir=/dev/shm/default,worker_id=0,bitmap_size=65536,input_buffer_size=131072,sharedir=/home/ubuntu/tdvfuzz/sharedir,ip0_a=0xffffffff81000000,ip0_b=0xffffffff83603000,ip1_a=0xffffffff86725000,ip1_b=0xffffffff86802000
# -device isa-serial,chardev=kafl_serial
# -chardev file,id=kafl_serial,mux=on,path=/dev/shm/default/serial_00.log
# -m 1024
# -d nyx
# -D /dev/shm/default/qemu_trace_00.log
# -kernel /home/ubuntu/tdvfuzz/linux-guest/arch/x86/boot/bzImage
# -initrd /home/ubuntu/tdvfuzz/initrd.cpio.gz
# -bios /home/ubuntu/tdvfuzz/TDVF.fd
# -append init=/sbin/init root=/dev/vda1 rw hprintf=4 lpj=300 force_tdx_guest tdx_wlist_devids=pci:0x8086:0x29c0,acpi:PNP0501 nokaslr nopti mitigations=off mce=off
# -fast_vm_reload path=/dev/shm/default/snapshot/,load=off

##
# Testing
##
QEMU = ~/tdvfuzz/kafl/qemu/x86_64-softmmu/qemu-system-x86_64
QEMU_FLAGS = -m $(MEM) -nographic \
	-enable-kvm \
	-machine kAFL64-v1 \
	-cpu kAFL64-Hypervisor-v1,+vmx \
	-drive if=pflash,format=raw,readonly,file=$(TDVF_CODE) \
	-drive if=pflash,format=raw,file=$(TDVF_VARS) \
	-nodefaults

run:
	$(QEMU) $(QEMU_FLAGS)

debug:
	$(QEMU) $(QEMU_FLAGS) -s -S

.PHONY:	run debug bnr
