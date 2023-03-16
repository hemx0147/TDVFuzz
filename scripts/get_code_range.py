#!/bin/env python

import re
import os
import glob
import argparse
from typing import Tuple, Dict
# kafl/fuzzer dir is already module search path
from scripts.tdvf_module import *


# memory addresses have typical hex format (length 10 to 12)
ADDRESS_RE = re.compile(r'0x[0-9a-fA-F]{8,16}')


def get_module_name_from_line(module_line: str) -> str:
    '''get the module name from a qemu debug log line'''
    # "\w" = any word characters (characters from a to Z, digits from 0-9, and the underscore _ character)
    module_file_re = re.compile(r'\w+\.efi$')
    module_file = module_file_re.search(module_line).group()
    name = re.sub(r'\.efi$', "", module_file)
    assert name is not None, "no module name found"
    return name

def get_module_address_from_line(module_line: str) -> Address:
    '''get the module image base address from a qemu debug log line'''
    address = ADDRESS_RE.search(module_line).group()
    assert address is not None, "no module address found"
    return Address(address)

def get_driver_modules(log_file:str) -> Dict[str, TdvfModule]:
    '''search for loaded driver information in a qemu logfile and return a mapping of module names to module objects with name & image base address'''
    with open(log_file, 'r') as f:
        log_lines = list(line.strip() for line in f.readlines())

    driver_line_re = re.compile(r'Loading driver at 0x.*EntryPoint=0x.*\.efi')
    # DXE Core module line is special - it does not follow the general line-pattern for drivers
    dxe_core_line_re = re.compile(r'Loading DXE CORE at 0x')

    modules = {}
    for line in log_lines:
        if driver_line_re.search(line):
            name = get_module_name_from_line(line)
            if "HelloWorld" in name:
                # ignore HelloWorld.efi module
                continue
            address = get_module_address_from_line(line)
        elif dxe_core_line_re.search(line):
            name = "DxeCore"
            address = get_module_address_from_line(line)
        else:
            # line does not contain loaded driver info
            continue
        modules[name] = TdvfModule(name, address)
    return modules

def get_secmain_name_and_address(map_file: str) -> Tuple[str, Address]:
    '''obtain the base address of the SecMain module from a FV map file'''
    with open(map_file, 'r') as f:
        lines = list(line.strip() for line in f.readlines())
    ba_re = re.compile(r'BaseAddress=' + ADDRESS_RE.pattern)
    base_addr_line = next(filter(lambda line: re.findall(ba_re, line), lines))
    base_addr = re.findall(ba_re, base_addr_line)[0].split('=')[1]
    return 'SecMain', Address(base_addr)

def get_module_debug_file_paths(build_dir: str) -> Dict[str, str]:
    '''find all module .debug files in directory search_dir and return a dict of modules and their paths'''
    x64_dir = build_dir + '/**/DEBUG_GCC5/X64'
    search_dir = glob.glob(x64_dir, recursive=True)[0]
    path_list = glob.glob(search_dir + '/*.debug', recursive=False)
    assert path_list, "list of module debug files is empty"

    module_paths = {}
    for path in path_list:
        base_name = path.split('/')[-1]
        name = re.sub(r"\.debug$", "", base_name)
        
        # There are two CpuDxe debug files (with different GUID added to filename). For now, we just remove the GUID & don't care about which CpuDxe debug is used.
        #TODO: figure out which CpuDxe module is used or load both
        # remove potential guid-part from file name
        # regex guid modified from https://uibakery.io/regex-library/guid-regex-python
        guid_part_re = re.compile(r'_(?:[0-9a-fA-F]){8}-(?:[0-9a-fA-F]){4}-(?:[0-9a-fA-F]){4}-(?:[0-9a-fA-F]){4}-(?:[0-9a-fA-F]){12}')
        name = re.sub(guid_part_re, "", name)

        module_paths[name] = os.path.abspath(path)
    return module_paths

def find_secmap_file_path(build_dir: str) -> str:
    '''find the SecMain module FV map file and return its path'''
    f_str = build_dir + "/**/DEBUG_GCC5/FV/SECFV.Fv.map"
    path = glob.glob(f_str, recursive=True)[0]
    assert path, f"invalid path to SEC FV map file '{path}'"
    return path

def dir_path(path):
    if os.path.isdir(path):
        return path
    else:
        raise NotADirectoryError(path)

def file_path(path):
    if os.path.isfile(path):
        return path
    else:
        raise FileNotFoundError(path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Obtain IntelPT code ranges for TDVF modules loaded in a qemu session. ',
        epilog='Information about which modules were loaded needs to be provided by a qemu debug log file. The .text section information will be extracted from TDVF .debug build files. This script requires the python pyelftools package.'
    )
    parser.add_argument(
        'logfile',
        metavar='LOGFILE',
        type=file_path,
        help='Path to a file containing debug prints of a qemu TDVF session'
    )
    parser.add_argument(
        'builddir',
        metavar='BUILDDIR',
        type=dir_path,
        help='Path to TDVF Build directory containing TDVF module .debug and FV map files (e.g. tdvf/Build)'
    )
    parser.add_argument(
        'module',
        metavar='MODULE',
        type=str,
        nargs='*',
        help='Name of the TDVF module whose code range should be displayed. If this option is omitted, the code ranges for all loaded modlues will be displayed.'
    )

    me_group = parser.add_mutually_exclusive_group()
    me_group.add_argument(
        '-t',
        '--table',
        action='store_true',
        help='print the module information in a fancy table. If this option is omitted, only module name, image base and .text start & end will be displayed.'
    )
    me_group.add_argument(
        '-j',
        metavar='FILENAME',
        type=str,
        help='store the module information in a json file'
    )

    args = parser.parse_args()

    # variables set by command line arguments
    log_file = args.logfile
    build_dir = args.builddir
    search_modules = args.module     # value is None if no argument given
    print_table = args.table
    json_file = args.j

    # parse debug log to get list of modules with their base address
    modules = get_driver_modules(log_file)

    # add entry for SecMain module (base address is in FV map file instead of qemu debug log)
    secmap = find_secmap_file_path(build_dir)
    sec_name, sec_address = get_secmain_name_and_address(secmap)
    modules[sec_name] = TdvfModule(sec_name, sec_address)

    # build TDVF module table
    module_table = TdvfModuleTable(modules)

    # find module debug files & add paths
    module_paths = get_module_debug_file_paths(build_dir)
    for name, module in module_table.modules.items():
        module.d_path = module_paths[name]

    # add missing .text info
    module_table.fill_text_info()

    if json_file:
        module_table.write_to_file(search_modules, json_file)
    else:
        # print module information
        if print_table:
            module_table.print_table(search_modules)
        else:
            module_table.print_short(search_modules)