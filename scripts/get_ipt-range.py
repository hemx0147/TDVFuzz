#!/bin/env python

import re
import glob
import argparse
from typing import Tuple, Dict

# add tdvf module class file to search path for module imports
import sys
sys.path.append('../kafl/fuzzer/scripts')
from tdvf_module import *


# memory addresses have typical hex format (length 10 to 12)
ADDRESS_RE = re.compile(r'0x[0-9a-fA-F]{8,16}')


def get_module_name_from_line(module_line: str) -> str:
    '''get the module name from a qemu debug log line'''
    # "\w" = any word characters (characters from a to Z, digits from 0-9, and the underscore _ character)
    module_file_re = re.compile(r'\w+\.efi$')
    module_file = module_file_re.search(module_line).group()
    name = module_file.strip('.efi')
    assert name is not None, "no module name found"
    return name

def get_module_address_from_line(module_line: str) -> str:
    '''get the module image base address from a qemu debug log line'''
    address = ADDRESS_RE.search(module_line).group()
    assert address is not None, "no module address found"
    return address

def get_driver_modules_and_addresses(log_file:str) -> Dict[str, str]:
    with open(log_file, 'r') as f:
        log_lines = list(line.strip() for line in f.readlines())

    driver_line_re = re.compile(r'Loading driver at 0x')
    # DXE Core module line is special - it does not follow the general line-pattern for drivers
    dxe_core_line_re = re.compile(r'Loading DXE CORE at 0x')

    modules = {}
    for line in log_lines:
        if driver_line_re.search(line):
            name = get_module_name_from_line(line)
            address = get_module_address_from_line(line)
        elif dxe_core_line_re.search(line):
            name = "DxeCore"
            address = get_module_address_from_line(line)
        else:
            # line does not contain loaded driver info
            continue
        modules[name] = address
    return modules

def get_secmain_name_and_address(map_file: str) -> Tuple[str, str]:
    '''obtain the base address of the SecMain module from a FV map file'''
    with open(map_file, 'r') as f:
        lines = list(line.strip() for line in f.readlines())
    ba_re = re.compile(r'BaseAddress=' + ADDRESS_RE.pattern)
    base_addr_line = next(filter(lambda line: re.findall(ba_re, line), lines))
    base_addr = re.findall(ba_re, base_addr_line)[0].split('=')[1]
    return 'SecMain', base_addr

def find_debug_file_paths(build_dir: str) -> Dict[str, str]:
    '''find all module .debug files in directory search_dir and return a dict of modules and their paths'''
    search_dir = glob.glob(build_dir + '**/DEBUG_GCC5/X64', recursive=True)
    path_list = glob.glob(search_dir + "/*.debug", recursive=False)
    assert path_list, "list of module debug files is empty"

    module_paths = {}
    for path in path_list:
        name = path.split('/')[-1].strip('.debug')
        module_paths[name] = path
    return module_paths

def find_secmap_file_path(build_dir: str) -> str:
    '''find the SecMain module FV map file and return its path'''
    f_str = build_dir + "/**/DEBUG_GCC5/FV/SECFV.Fv.map"
    path = glob.glob(f_str, recursive=True)[0]
    assert path, f"invalid path to SEC FV map file '{path}'"
    return path




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
        'builddir',
        metavar='BUILDDIR',
        type=str,
        help='Path to TDVF Build directory containing TDVF module .debug and FV map files (e.g. tdvf/Build)'
    )

    parser.add_argument(
        'module',
        metavar='MODULE',
        type=str,
        nargs='?',
        help='Name of the TDVF module whose code range should be displayed. If this option is omitted, the code ranges for all loaded modlues will be displayed.'
    )

    args = parser.parse_args()

    # variables set by command line arguments
    log_file = args.logfile
    build_dir = args.builddir
    search_module = args.module     # value is None if no argument given


    # parse debug log to get list of modules and their base address
    module_dict = get_driver_modules_and_addresses(log_file)

    # add entry for SecMain module (base address is in FV map file instead of qemu debug log)
    secmap = find_secmap_file_path(build_dir)
    sec_name, sec_address = get_secmain_name_and_address(secmap)
    module_dict[sec_name] = sec_address

    # find module debug files
    module_paths = find_debug_file_paths(build_dir)

    # build TDVF module table
    module_table = TdvfModuleTable()
    for module, address in module_dict.values():
        m = TdvfModule(module)
        m.img_base = address
        m.d_path = module_paths[module]
        m.fill_text_info
        module_table.add_module(m)
        
    # print module information
    if search_module:
        # for a single module, only return image base and .text "start-end" so it can be further processed by other programs
        m = module_table.get_module(search_module)
        print(f'{m.name} {m.img_base} {m.t_start}-{m.t_end}')
        exit(0)

    module_table.print_table()