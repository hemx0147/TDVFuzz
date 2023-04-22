#!/bin/env python

import argparse
import sys
import os
import re
from collections import Counter, OrderedDict

##
# Count occurences of the different exception types for fuzzing session
# findings (crash, kasan, timeout) and list them on stdout.
#
# Parameters:
#   -d      Path to a directory containing the findings log files (e.g. $KAFL_WORKDIR/logs).
#   FILE    Path to a findings log file (e.g. crash_12345.log)
##


# list of exception codes & names obtained from https://wiki.osdev.org/Exceptions
EXCEPTIONS = {
  0x0: 'Division Error',
  0x1: 'Debug',
  0x2: 'Non-maskable Interrupt',
  0x3: 'Breakpoint',
  0x4: 'Overflow',
  0x5: 'Bound Range Exceeded',
  0x6: 'Invalid Opcode',
  0x7: 'Device Not Available',
  0x8: 'Double Fault',
  0x9: 'Coprocessor Segment Overrun',
  0xA: 'Invalid TSS',
  0xB: 'Segment Not Present',
  0xC: 'Stack-Segment Fault',
  0xD: 'General Protection Fault',
  0xE: 'Page Fault',
  0xF: 'Reserved',
  0x10: 'x87 Floating-Point Exception',
  0x11: 'Alignment Check',
  0x12: 'Machine Check',
  0x13: 'SIMD Floating-Point Exception',
  0x14: 'Virtualization Exception',
  0x15: 'Control Protection Exception',
  0x16: 'Reserved',
  0x17: 'Reserved',
  0x18: 'Reserved',
  0x19: 'Reserved',
  0x1A: 'Reserved',
  0x1B: 'Reserved',
  0x1C: 'Hypervisor Injection Exception',
  0x1D: 'VMM Communication Exception',
  0x1E: 'Security Exception',
  0x1F: 'Reserved'
}

def error(msg: str):
  print('Error: ' + msg, file=sys.stderr)
  exit(1)

def dir_path(path):
  if not os.path.isdir(path):
    error(f'directory {path} not found.')
  return path

def file_path(path):
  if not os.path.isfile(path):
    error(f'file {path} not found.')
  return path

def get_log_files(dir_path: str):
  '''Return list of all log files in dir_path.'''
  all_files = os.listdir(dir_path)
  log_files = [dir_path + '/' + lf for lf in list(filter(lambda fname: ".log" in fname, all_files))]
  return log_files

def file_get_exceptions(fpath: str):
  '''Return a mapping of exception codes to number of occurences for this file'''
  with open(fpath, 'r') as f:
    exceptions = list(filter(lambda line: 'Exception Type' in line, f.readlines()))
  
  # reduce whole lines to only exception code
  ec_re = re.compile(r'Exception Type - [0-9A-F]{1,2}')
  exception_codes = list(map(lambda ec: int(ec, 16), list(map(lambda ex: ec_re.findall(ex)[0].split(' ')[-1], exceptions))))
  
  return OrderedDict(sorted(dict(Counter(exception_codes)).items()))

def get_exceptions(fpaths: list):
  '''Return a mapping of exception codes to number of occurences for each file in given file path list'''

  c = Counter()
  for fpath in fpaths:
    c.update(file_get_exceptions(fpath))
  
  return OrderedDict(sorted(dict(c).items()))

def print_exception_count(exceptions: dict):
  '''print the given exception count in readable way'''
  for ex_code, ex_count in exceptions.items():
    print(f'{EXCEPTIONS[ex_code]} ({hex(ex_code)}): {ex_count}')


if __name__ == "__main__":
  parser = argparse.ArgumentParser(
    description='Count occurences of the different exception types for fuzzing session findings (crash, kasan, timeout).',
    epilog='Logfiles can be provided either directly or by specifying the log-file directory using the -d option.'
  )
  parser.add_argument(
    'logfile',
    metavar='LOGFILE',
    # type=file_path,
    nargs='*',
    help='Path to a findings log file (e.g. crash_12345.log)'
  )
  parser.add_argument(
    '-d',
    metavar='LOGDIR',
    type=dir_path,
    help='Path to a directory containing the findings log files (e.g. $KAFL_WORKDIR/logs).'
  )

  args = parser.parse_args()

  # variables set by command line arguments
  log_files = args.logfile
  log_dir = args.d

  if not log_files and not log_dir:
    error('specify at least one log file or a logfile directory.')

  if log_dir:
    log_files = get_log_files(log_dir)


  exceptions = get_exceptions(log_files)
  print_exception_count(exceptions)