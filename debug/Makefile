#!/usr/bin/env make


MEM=1G
LOG=debug.log
BASE_DIR=/home/ryannick/qemu-test
FAT_DIR=$(BASE_DIR)/fat-dir

# OVMF
OVMF_DIR=$(BASE_DIR)/OVMF
OVMF_BASE=$(OVMF_DIR)/edk2/Build/OvmfX64/DEBUG_GCC5/FV
OVMF_BIN=$(OVMF_BASE)/OVMF.fd
OVMF_CODE=$(OVMF_BASE)/OVMF_CODE.fd
OVMF_VARS=$(OVMF_BASE)/OVMF_VARS.fd

QEMU_NATIVE:=qemu-system-x86_64
QEMU_FLAGS_OVMF=-m $(MEM) -nographic \
    -drive if=pflash,format=raw,readonly,file=$(OVMF_CODE) \
    -drive if=pflash,format=raw,file=$(OVMF_VARS) \
    -drive if=virtio,format=raw,file=fat:rw:$(FAT_DIR) \
    -debugcon file:$(OVMF_DIR)/$(LOG) -global isa-debugcon.iobase=0x402 \
	-serial stdio \
	-nodefaults


# qemu_base=-m $(MEM) \
#     -nographic \
#     -vga none \
#     -no-reboot \
#     -net none \
#     -enable-kvm \
#     -smp 4,sockets=2 \
#     -machine kAFL64-v1 \
#     -cpu kAFL64-Hypervisor-v1,+vmx \
#     -display none \
#     -device loader,file=$(TDVF_BIN),id=fd0
#     -bios $(TDVF_BIN)
#     -drive if=pflash,format=raw,file=$(TDVF_BIN)
#     -drive if=pflash,format=raw,readonly,file=$(TDVF_CODE)
#     -drive if=pflash,format=raw,file=$(TDVF_VARS)
#     -drive if=virtio,format=raw,file=fat:rw:$(FAT_DIR)
#     -name debug-threads=on

# TDVF
TDVF_DIR=$(BASE_DIR)/TDVF
TDX_DIR=/home/ryannick/tdx
TDVF_BASE=$(TDX_DIR)/kafl/edk.git/Build/OvmfX64/DEBUG_GCC5/FV
TDVF_BIN=$(TDVF_BASE)/OVMF.fd
TDVF_CODE=$(TDVF_BASE)/OVMF_CODE.fd
TDVF_VARS=$(TDVF_BASE)/OVMF_VARS.fd
TDX_GUEST=$(TDX_DIR)/linux-guest
LINUX_KERNEL=$(TDX_GUEST)/arch/x86_64/boot/bzImage
LINUX_INITRD=$(TDX_DIR)/initrd.cpio.gz
WORKDIR=/dev/shm/ryannick_tdfl
SHAREDIR=/home/ryannick/tdx/sharedir
IPT_RANGE=ip0_a=0xfffcc094,ip0_b=0xffffffff,ip1_a=0xffffffff86725000,ip1_b=0xffffffff86802000

QEMU_TDVF=$(TDX_DIR)/kafl/qemu/x86_64-softmmu/qemu-system-x86_64
QEMU_APPEND="init=/sbin/init root=/dev/vda1 rw hprintf=4 lpj=300 force_tdx_guest tdx_wlist_devids=pci:0x8086:0x29c0,acpi:PNP0501 nokaslr nopti mitigations=off mce=off"
QEMU_FLAGS_TDVF=-enable-kvm \
        -machine kAFL64-v1 \
        -cpu kAFL64-Hypervisor-v1,+vmx \
        -smp 1 \
        -no-reboot \
        -display none \
        -nodefaults \
        -netdev user,id=mynet0 \
        -device virtio-net,netdev=mynet0 \
        -virtfs local,path=/tmp/kafl,mount_tag=tmp,security_model=mapped-file \
        -device virtio-serial \
        -device virtconsole,chardev=kafl_serial \
        -device isa-serial,chardev=kafl_serial \
        -chardev socket,server,id=nyx_socket,path=$(WORKDIR)/interface_0 \
        -device nyx,chardev=nyx_socket,workdir=$(WORKDIR),worker_id=0,bitmap_size=65536,input_buffer_size=131072,sharedir=$(SHAREDIR),$(IPT_RANGE) \
        -device isa-serial,chardev=kafl_serial \
        -chardev file,id=kafl_serial,mux=on,path=$(WORKDIR)/serial_00.log \
        -m 1024 \
        -kernel $(LINUX_KERNEL) \
        -initrd $(LINUX_INITRD) \
        -bios $(TDVF_BIN) \
        -append $(QEMU_APPEND) \
        -fast_vm_reload path=$(WORKDIR)/snapshot/,load=off



run:
	$(QEMU_NATIVE) $(QEMU_FLAGS_OVMF)

run-tdvf:
	$(QEMU_TDVF) $(QEMU_FLAGS_TDVF)

debug:
	$(QEMU_NATIVE) $(QEMU_FLAGS_OVMF) -s -S

debug-tdvf:
	$(QEMU_TDVF) $(QEMU_FLAGS_TDVF) -s -S

.PHONY:	run	run-tdvf debug debug-tdvf
