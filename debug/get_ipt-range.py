#!/bin/env python

import re
import glob
import argparse
from enum import Enum
from elftools.elf.elffile import ELFFile

# memory addresses have typical hex format (length 10 to 12)
ADDRESS_RE = re.compile(r'0x[0-9a-fA-F]{8,16}')

# some syntactic sugar for working with module dict
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
    '''
    create a dict matching module name to base-, text-start- & text-end-addresses as well as text size and path to the module debug file.
    module_dict: {name: {base, t_start, t_end, t_size, debug_path}}
    ''' 
    with open(file_name, 'r') as f:
        lines = list(line.strip() for line in f.readlines())
    
    module_dict = {}

    # get all "loading driver at ..." lines
    module_line_re = re.compile(r'Loading driver at 0x')
    driver_lines = list(filter(lambda line: re.match(module_line_re, line), lines))
    for line in driver_lines:
        module_name = get_module_name_from_line(line)
        module_address = get_module_address_from_line(line)
        module_dict[module_name] = {MD.mbase: module_address, MD.tstart: "", MD.tend: "", MD.tsize: "", MD.dpath:""}

    # DXE Core module line is special - it does not follow the general line-pattern for drivers
    dxe_core_line_re = re.compile(r'Loading DXE CORE at 0x')
    dxe_core_line = next(filter(lambda line: re.match(dxe_core_line_re, line), lines))
    dxe_core_name = "DxeCore"
    dxe_core_address = get_module_address_from_line(dxe_core_line)
    module_dict[dxe_core_name] = {MD.mbase: dxe_core_address, MD.tstart: "", MD.tend: "", MD.tsize: "", MD.dpath:""}
    return module_dict

def find_debug_file_paths(search_dir: str) -> list:
    '''find all module .debug files in directory search_dir and return their paths'''
    debug_dir = search_dir + "/IntelTdx/DEBUG_GCC5/X64"
    file_str = debug_dir + "/*.debug"
    path_list = glob.glob(file_str, recursive=False)
    assert path_list, "list of module debug files is empty"
    return path_list

def find_secmap_file_path(search_dir: str) -> str:
    '''find the SecMain module FV map file and return its path'''
    f_str = search_dir + "/**/SECFV.Fv.map"
    path = glob.glob(f_str, recursive=True)[0]
    assert path, f"invalid path to SEC FV map file '{path}'"
    return path

def get_secmain_base(map_file: str) -> str:
    '''obtain the base address of the SecMain module from a FV map file'''
    with open(map_file, 'r') as f:
        lines = list(line.strip() for line in f.readlines())
    ba_re = re.compile(r'BaseAddress=' + ADDRESS_RE.pattern)
    base_addr_line = next(filter(lambda line: re.findall(ba_re, line), lines))
    base_addr = re.findall(ba_re, base_addr_line)[0].split('=')[1]
    return base_addr

def pretty_print_module_dict(module_dict: dict) -> None:
    '''print all found modules and the obtained module info in a table'''
    if not module_dict:
        return
    
    print(f'{"Module Name":<32} {"Image Base":<16} {".text Start":<16} {".text End":<16} {"Size":<6}')
    print('-' * 90)
    for module, modinfo in module_dict.items():
        ibase = str_to_hexaddress(modinfo[MD.mbase], False)
        tstart = str_to_hexaddress(modinfo[MD.tstart], False)
        tend = str_to_hexaddress(modinfo[MD.tend], False)
        tsize = modinfo[MD.tsize][2:]
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
    module_dict = build_module_dict(log_file)

    # add entry for SecMain module (base address is in FV map file instead of qemu debug log)
    secmap = find_secmap_file_path(build_dir)
    sec_base_address = get_secmain_base(secmap)
    module_dict['SecMain'] = {MD.mbase: sec_base_address, MD.tstart: "", MD.tend: "", MD.tsize: "", MD.dpath:""}

    # find module debug files
    module_paths = find_debug_file_paths(build_dir)

    # assign missing info to modules
    for module, values in module_dict.items():
        if search_module:
            # skip all other modules if code range is wanted only for a specific module
            if module != search_module:
                continue

        # add module debug files paths
        module_path = next(filter(lambda path: module in path, module_paths))
        assert module_path, "invalid path to module debug file"
        values[MD.dpath] = module_path
    
        # add module .text start, end & size
        with open(module_path, 'rb') as f:
            module_elf = ELFFile(f)
            for section in module_elf.iter_sections():
                if not section.name.startswith('.text'):
                    continue
                tsize_num = section.header['sh_size']
                tstart_num = int(values[MD.mbase], 16) + section.header['sh_addr']
                tend_num = tstart_num + tsize_num
                values[MD.tstart] = hex(tstart_num)
                values[MD.tend] = hex(tend_num)
                values[MD.tsize] = hex(tsize_num)
        
    
    # sort module dict by key
    module_dict = {key: val for key, val in sorted(module_dict.items(), key = lambda k: k[0])}

    # print module information
    if search_module:
        # for a single module, only return .text "start-end" so it can be further processed by other programs
        module_info = module_dict[search_module]
        print(f'{module_info[MD.tstart]}-{module_info[MD.tend]}')
    else:
        pretty_print_module_dict(module_dict)