#!/bin/env python

# configure kAFL fuzzing harnesses for TDVF
# behavior should be similar to $LINUX_GUEST/scripts/config, but for now only directly modify BaseLib (no config file)


# argument parsing:
# -e | --enable <FLAGNAME>
#   open config file, set FLAGNAME to true ("=y")
#   find "#define FLAGNAME" in TDVF BaseLib 
#   if line commented out (i.e. "// " at beginning), uncomment (i.e. remove "// ")
#   if line not commented out, do nothing
# -d | --disable <FLAGNAME>
#   open config file, set FLAGNAME to false ("# FLAGNAME is not set")
#   find "#define FLAGNAME" in TDVF BaseLib 
#   if line commented out (i.e. "// " at beginning), do nothing
#   if line not commented out, out-comment line (i.e. add "// ")
# -p | --print
#   print current config (i.e. contents of config file and/or "#define FLAGNAME" lines in TDVF BaseLib)

import os
from enum import Enum
from pathlib import Path
from typing import List, Dict
from argparse import ArgumentParser


# filled from env var
# TODO: add error handling if env vars / baselib cannot be found
g_tdvf_root = os.environ["TDVF_ROOT"]
g_baselib_path = str(next(Path(g_tdvf_root).rglob('BaseLib.h')))
g_config_boundary_start = "/** KAFL HARNESS CONFIGURATION START **/"
g_config_boundary_end = "/** KAFL HARNESS CONFIGURATION END **/"
g_eol = '\r\n'

class Action(Enum):
  ENABLE = 0
  DISABLE = 1
  PRINT = 2

class Flag(Enum):
  FUZZ_BOOT_LOADER = "CONFIG_KAFL_FUZZ_BOOT_LOADER"
  FUZZ_VIRTIO_READ = "CONFIG_KAFL_FUZZ_VIRTIO_READ"
  FUZZ_BLK_DEV_INIT = "CONFIG_KAFL_FUZZ_BLK_DEV_INIT"


def load_baselib(baselib: str) -> List[str]:
  '''
  Read-in the TDVF BaseLib header file and split it by lines so its content can be modified
  @param baselib Path to the BaseLib header
  @return mapping of BaseLib line numbers to lines
  '''
  with open(baselib, 'r', newline='') as f:
    lines = f.readlines()
  
  if lines[0][-2:] == '\r\n':
    g_eol = '\r\n'
  else:
    g_eol = '\n'

  return lines

def create_config_lines(config: Dict[Flag, bool]) -> List[str]:
  '''
  Replace the kAFL harness configuration in TDVF BaseLib header
  '''
  comment_str = '// '
  def_str = '#define '
  config_lines = []
  for (flag, is_active) in config.items():
    prefix = comment_str
    if is_active:
      prefix = ''
    config_lines.append(prefix + def_str + flag.value + g_eol)
  return config_lines

def write_baselib(baselib: str, head: List[str], config: List[str], tail: List[str]) -> None:
  '''
  Write the given BaseLib parts back to file
  '''
  with open(baselib, 'w') as f:
    f.writelines(head)
    f.writelines(config)
    f.writelines(tail)

def split_lib_parts(lib_content: List[str]) -> tuple():
  '''
  Split library content in 3 parts: a part before harnes config, the harness config itself and a part after the harness config
  '''
  config_start = lib_content.index(g_config_boundary_start + g_eol) + 1
  config_end = lib_content.index(g_config_boundary_end + g_eol)
  head = lib_content[:config_start]
  config = lib_content[config_start:config_end]
  tail = lib_content[config_end:]
  return head, config, tail

def get_current_config(config_lines: List[str]) -> Dict[Flag, bool]:
  '''
  Obtain the current configuration from the given harness config lines of the library file
  '''
  config = {}
  for line in config_lines:
    for flag in Flag:
      if flag.value in line:
        is_active = True
        if line[:4] == "// #":
          # line is commented out
          is_active = False
        config[flag] = is_active
  return config
  
def enable_flag(flag: Flag, config: Dict[Flag, bool]) -> Dict[Flag, bool]:
  config.update({flag: True})
  return config

def disable_flag(flag: Flag, config: Dict[Flag, bool]) -> Dict[Flag, bool]:
  config.update({flag: False})
  return config

def print_config(config: Dict[Flag, bool]) -> None:
  '''
  Print the current kAFL harness configuration
  '''
  for flag, is_active in config.items():
    state = "enabled" if is_active else "disabled"
    print(f"{flag.name}: {state}")



if __name__ == "__main__":
  parser = ArgumentParser(description='Configure kAFL fuzzing harnesses for TDVF')
  me_group = parser.add_mutually_exclusive_group(required=True)
  me_group.add_argument(
    '-e',
    '--enable',
    metavar='FLAG',
    choices=Flag._member_names_,
    type=str,
    help='Enable the harness specified by the given flag'
  )
  me_group.add_argument(
    '-d',
    '--disable',
    metavar='FLAG',
    choices=Flag._member_names_,
    type=str,
    help='Disable the harness specified by the given flag'
  )
  me_group.add_argument(
    '-p',
    '--print',
    action='store_true',
    help='Print the current harness configuration'
  )
  args = parser.parse_args()

  # get current setup
  current_baselib = load_baselib(g_baselib_path)
  lib_head, crnt_lib_config, lib_tail = split_lib_parts(current_baselib)
  crnt_config = get_current_config(crnt_lib_config)

  # perform user-action
  if args.print:
    print_config(crnt_config)
    exit(0)

  # create copy of current lib
  # write_baselib(g_baselib_path + '.bkup', lib_head, crnt_lib_config, lib_tail)

  new_config = None
  if args.enable is not None:
    new_config = enable_flag(Flag._member_map_[args.enable], crnt_config)
  if args.disable is not None:
    new_config = disable_flag(Flag._member_map_[args.disable], crnt_config)

  new_lib_config = create_config_lines(new_config)
  write_baselib(g_baselib_path, lib_head, new_lib_config, lib_tail)
  # print("New Config")
  # print_config(new_config)