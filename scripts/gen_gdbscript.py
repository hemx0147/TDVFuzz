#!/bin/env python

# Create a GDB script file for importing debug symbols provided in a module json file

import os
import re
import argparse
from typing import List
# kafl/fuzzer dir is already module search path
from scripts.tdvf_module import *


MODULE_FILE='modules.json'
SCRIPT_FILE='gdbscript'


class HexAddress:
  '''Class representing hexadecimal addresses.'''

  def __init__(self, address: str):
    self.int_val = int(self.verify_hex_format(address), 16)
  
  def verify_hex_format(self, address: str):
    '''Verify that given address string has hex format.'''
    # memory addresses have typical hex format (length 1 to 16 for 64 bit), and can be specified either with or without '0x' prefix
    re_hex = re.compile(r'([0-9a-fA-F]{1,16})|(0x[0-9a-fA-F]{1,16})')
    if not re_hex.fullmatch(address):
      raise ValueError(f'argument is not a valid 64-bit hex address: {address}')
    return address

  @property
  def int_val(self) -> int:
    return self.__value

  @int_val.setter
  def int_val(self, new_val: int):
    self.__value = new_val

  @property
  def hex_val(self) -> str:
    return hex(self.__value)

  @hex_val.setter
  def hex_val(self, address: str):
    self.int_val = int(self.verify_hex_format(address), 16)

  def __repr__(self) -> str:
    return self.hex_val


def dir_path(path):
  if os.path.isdir(path):
    return path
  raise NotADirectoryError(path)

def file_path(path):
  if os.path.isfile(path):
    return path
  raise FileNotFoundError(path)

def hex_format(address):
  return HexAddress.verify_hex_format(address)

def create_import_line(module: TdvfModule) -> str:
  '''Build a module-import line for importing debug symbols using the `add-symbol-file` GDB command.'''
  if not module:
    raise ValueError('argument "module" is empty or None.')
  dbg = module.d_path
  base = module.img_base
  if not dbg:
    raise ValueError('module debug path is empty or None.')
  if not base:
    raise ValueError('module base address is empty or None.')
  return f"add-symbol-file {dbg} {base}"

def create_all_import_lines(modules:List[TdvfModule]) -> List[str]:
  '''Build all module-import lines to import all necessary debug symbols using the `add-symbol-file` GDB command.'''
  return list(create_import_line(m) for m in modules)

def create_attach_line() -> str:
  '''Build the line that attaches GDB to running qemu session using the `target` GDB command'''
  # qemu session is available at localhost on port 1234 by default
  return 'target remote localhost:1234'

def create_break_line(addr: HexAddress):
  '''Build the line that sets a hardware breakpoint using the `hbreak` GDB command'''
  assert isinstance(addr, HexAddress), f'argument is not of type HexAddress: "{addr}"'
  return f'hbreak *{addr.hex_val}'

def modules_from_json(file_name:str) -> List[TdvfModule]:
  '''Read module information from a json file and store them in a list of modules'''
  assert os.path.isfile(file_name), f'No such file "{file_name}"'

  with open(file_name, 'r') as f:
    module_info = json.load(f)
  
  modules = []
  for minfo in module_info:
    m = TdvfModule()
    m.from_dict(minfo)
    modules.append(m)
  return modules

def write_script_lines(lines: List[str], script:str = None):
  '''Write a list of gdbscript content lines to stdout, or to the file specified by the script argument.'''
  assert script is None or isinstance(script, str), f'invalid argument "{script}"'
  assert lines, 'list of script content must contain at least one line string'

  script_content = '\n'.join(lines)
  if not script:
    print(script_content)
    return

  with open(script, 'w') as f:
    f.write(script_content + '\n')



if __name__ == "__main__":
  parser = argparse.ArgumentParser(
    description='Print the content of a GDB that automatically imports module debug symbols, attaches to the running qemu session, and optionally sets a breakpoint at a given address when executed.',
    epilog='Information about the modules from which debug symbols should be imported into GDB needs to be provided by a module json file. This file can be created with the get_code_range.py script.'
  )
  parser.add_argument(
    '-m',
    metavar='MODULEFILE',
    type=file_path,
    help='Path to the module file containing information about the modules from which debug symbols should be imported (default: modules.json)',
    required=True,
    default=MODULE_FILE
  )
  parser.add_argument(
    'address',
    metavar='BREAKPOINT',
    type=str,
    nargs="?",
    help='64-bit memory address in hexadecimal format at which a breakpoint will be set.'
  )
  parser.add_argument(
    '-s',
    metavar='SCRIPTFILE',
    type=str,
    nargs="?",
    help='Write script contents into a file at the path specified by SCRIPTFILE (default: gdbscript)',
    const=SCRIPT_FILE
  )

  args = parser.parse_args()

  # variables set by command line arguments
  module_file = file_path(args.m)
  script_file = args.s
  break_addr = args.address

  modules = modules_from_json(module_file)
  script_lines = create_all_import_lines(modules)
  script_lines.append(create_attach_line())
  if break_addr:
    script_lines.append(create_break_line(HexAddress(break_addr)))
  write_script_lines(script_lines, script_file) 