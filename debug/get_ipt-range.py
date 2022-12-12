#!/bin/env python

# Obtain IntelPT code ranges for TDVF modules

# approach:
# 0. parse arguments
#   -h / --help   -> show help text
#   <module_name> -> get ipt range for this specific module (no output if module does not exist)
#   -l / --list   -> get ipt ranges for all modules & show in tabular overview (for each module show name, img base, text start, text end, text size)
#
# 1. get loaded module names & img base addresses
#   input = qemu debug log
#   file readlines, grep "Loading * at address..." -> dict[module_name: base-address]
#
# 2. get img base address for SecMain (static, not in qemu debug log)
#   input = SecMain FV map file
#   file readlines, grep "text-baseaddress=..." -> add to module-base dict
#
# 3. get names & paths of all module debug files
#   input = tdvf search_dir search_dir
#   glob(tdvf_root/*.debug), split results
#   Q: duplicate modules? GUID comparison necessary? recursive search?
#
# 4. parse debug files (i.e. elf files) & extract .text offset & size
#   input = module debug file
#   pyelftools get section .text
#
# 5. compute actual text start & end
#   input = module base addr, module text start & size
#   text-start = module-offset + text-offset
#   text-end = text-start + text-size
#
# 6. output desired info
#   - script input = single module: text_start-text_end   <- can be copy-pasted into fuzzer command line
#   - script input = --list: tabular output

import re
import glob
import argparse
from enum import Enum
from elftools.elf.elffile import ELFFile

# memory addresses have typical hex format (length 10 to 12)
ADDRESS_RE = re.compile(r'0x[0-9a-fA-F]{10,12}')

class MD(Enum):
    mbase = 'img_base'
    tstart = 'text_start'
    tend = 'text_end'
    tsize = 'text_size'
    dpath = 'debug_path'


def int_to_hexaddress(address: int, prefix_0x:bool = True) -> str:
    '''format an address value (int) to hex-address format ("0x"-prefix followed by 16 hex chars)'''
    hexval = hex(address)[2:]   # hex address without '0x' prefix
    prefix = ''
    if prefix_0x:
        prefix = '0x'
    return prefix + '{0:0>16}'.format(hexval)

def str_to_hexaddress(address: str, prefix:bool = True) -> str:
    '''format an address value string to hex-address format ("0x" followed by 16 hex chars)'''
    return int_to_hexaddress(int(address, 16), prefix)

def get_module_name_from_line(module_line: str) -> str:
    '''get the module name from a qemu debug log line'''
    # "\w" = any word characters (characters from a to Z, digits from 0-9, and the underscore _ character)
    module_file_re = re.compile(r'\w+\.efi$')
    module_file = re.findall(module_file_re, module_line)[0]
    module_name = module_file.split('.efi')[0]
    assert module_name is not None, "no module name found"
    return module_name

def get_module_address_from_line(module_line: str) -> str:
    '''get the module base address from a qemu debug log line'''
    module_address = re.findall(ADDRESS_RE, module_line)[0]
    assert module_address is not None, "no module address found"
    return module_address

def build_module_dict(file_name: str, module_name=None) -> dict:
    with open(file_name, 'r') as f:
        lines = list(line.strip() for line in f.readlines())
    
    # dict matching module name to base-, text-start- & text-end-address: {name: {base, t_start, t_end, t_size, debug_path}}
    module_dict = {}

    # TODO: add SecMain module

    # get all "loading driver at ..." lines
    module_line_re = re.compile(r'Loading driver at 0x')
    driver_lines = list(filter(lambda line: re.match(module_line_re, line), lines))
    for line in driver_lines:
        module_name = get_module_name_from_line(line)
        module_address = get_module_address_from_line(line)
        # key: module name, value: [img_base, text_start, text_end, text_size, debug_path]
        module_dict[module_name] = {MD.mbase: module_address, MD.tstart: "", MD.tend: "", MD.tsize: "", MD.dpath:""}

    # DXE Core module line is special - it does not follow the line-pattern for general drivers
    dxe_core_line_re = re.compile(r'Loading DXE CORE at 0x')
    dxe_core_line = next(filter(lambda line: re.match(dxe_core_line_re, line), lines))
    dxe_core_name = "DxeCore"
    dxe_core_address = get_module_address_from_line(dxe_core_line)
    module_dict[dxe_core_name] = {MD.mbase: dxe_core_address, MD.tstart: "", MD.tend: "", MD.tsize: "", MD.dpath:""}
    return module_dict

def find_debug_file_paths(search_dir: str) -> list:
    '''find all module .debug files in directory search_dir and return their paths'''
    f_str = search_dir + "/*.debug"
    path_list = glob.glob(f_str, recursive=False)
    assert path_list, "list of module debug files is empty"
    return path_list

def pretty_print_module_dict(module_dict: dict) -> None:
    if not module_dict:
        return
    
    # fix column widths of printed table
    # print(f'{"Module Name":<32} {"Image Base":<16} {".text Start":<16} {".text End":<16} {"Size":<6} {"Path to Debug File"}')
    print(f'{"Module Name":<32} {"Image Base":<16} {".text Start":<16} {".text End":<16} {"Size":<6}')
    print('-' * 90)
    for module, modinfo in module_dict.items():
        ibase = str_to_hexaddress(modinfo[MD.mbase], False)
        tstart = str_to_hexaddress(modinfo[MD.tstart], False)
        tend = str_to_hexaddress(modinfo[MD.tend], False)
        tsize = modinfo[MD.tsize][2:]
        # dpath = modinfo[MD.dpath].split('tdvf/')[1]
        # print(f'{module:<32} {ibase:<16} {tstart:<16} {tend:<16} {tsize :0<6} {dpath}')
        print(f'{module:<32} {ibase:<16} {tstart:<16} {tend:<16} {tsize:0>6}')



if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Obtain IntelPT code ranges for TDVF modules loaded in a qemu session. ',
        epilog='Information about which modules were loaded needs to be provided by a qemu debug log file. The .text section information will be extracted from TDVF .debug build files. This script requires the python pyelftools package.'
    )

    parser.add_argument(
        'logfile',
        metavar='LOGFILE',
        type=str,
        help='Path to a file containing debug prints of a qemu TDVF session'
    )

    parser.add_argument(
        'debugdir',
        metavar='DEBUGDIR',
        type=str,
        help='Path to a directory containing TDVF module .debug files (e.g. tdvf/Build/IntelTdx/DEBUG_GCC5/X64)'
    )

    parser.add_argument(
        'module',
        metavar='MODULE',
        type=str,
        nargs='?',
        help='Name of the TDVF module whose code range should be displayed. If this option is omitted, the code ranges for all loaded modlues will be displayed.'
    )

    args = parser.parse_args()
    log_file = args.logfile
    debug_path = args.debugdir
    search_module = args.module     # value is None if no argument given

    # parse debug log to get list of modules and their base address
    module_dict = build_module_dict(log_file)

    # find module debug files
    module_paths = find_debug_file_paths(debug_path)

    # assign debug file paths to their modules
    for module, values in module_dict.items():
        module_path = next(filter(lambda path: module in path, module_paths))
        assert module_path, "invalid path to module debug file"
        values[MD.dpath] = module_path
        # print(f"{module}: {module_dict[module]}")
    
        # grep text base & size
        with open(module_path, 'rb') as f:
            module_elf = ELFFile(f)
            for section in module_elf.iter_sections():
                if section.name.startswith('.text'):
                    tsize_num = section.header['sh_size']
                    tstart_num = int(values[MD.mbase], 16) + section.header['sh_addr']
                    tend_num = tstart_num + tsize_num
                    values[MD.tstart] = hex(tstart_num)
                    values[MD.tend] = hex(tend_num)
                    values[MD.tsize] = hex(tsize_num)
        
    
    # sort module dict by key
    module_dict = {key: val for key, val in sorted(module_dict.items(), key = lambda k: k[0])}

    # print stuff
    pretty_print_module_dict(module_dict)