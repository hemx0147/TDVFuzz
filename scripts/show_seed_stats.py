import re
import os
import argparse

SCRIPTS_DIR = os.environ["BKC_ROOT"] + '/scripts'
LOG_FILE = SCRIPTS_DIR + '/fuzz.log'

PL_RE = re.compile(r"payload_[0-9a-zA-Z_-]+")
SEED_RE = re.compile(r"seed_[0-9]+")
COPY_RE = re.compile(r"copying .* -> seed_[0-9]+")
USEFUL_RE = re.compile(r"Received new input .*:")
USELESS_RE = re.compile(r"Worker-[0-9]+ Imported payload produced no new coverage, skipping\.\.")
INVALID_RE = re.compile(r"Worker-[0-9]+ (Input validation failed! Target funky\?\.\.|Guest ABORT:.+)")

def get_seeds_from_attribute(lines: dict, attr_re) -> list:
  attr_lines = {i: line for i, line in lines.items() if attr_re.match(line)}
  seed_lines = [lines[i-1] for i in attr_lines.keys()]
  return [SEED_RE.findall(line)[0] for line in seed_lines if SEED_RE.findall(line)]

def print_seed_stats(attr_map):
  for attr, seeds in attr_map.items():
    if (len(seeds) > 0):
      for seed in seeds:
        print(f'{seed} {attr}')

def print_payload_stats(pl_map, attr_map):
  for attr, seeds in attr_map.items():
    if (len(seeds) > 0):
      for seed in seeds:
        print(f'{seed} {pl_map[seed]} {attr}')

if __name__ == "__main__":
  parser = argparse.ArgumentParser(
    description='Show which seeds were useful, useless or invalid in a fuzzing session.',
    epilog='Whether a seed is useful, useless or invalid is determined (and printed as information on console) by fuzzer. Seeds are deemed useful if they caused coverage of new paths, useless if no new paths were discovered and invalid if errors or fuzzer aborts were caused while/after loading the seed. Since the fuzzer copies files from the seed directory into its /import dir under a new name, this script requires the fuzzer to print out the source and destination names of the copied seeds.'
  )
  parser.add_argument(
    '-l',
    metavar='LOGFILE',
    type=str,
    help='Path to a file containing debug prints of a qemu TDVF session (default: BKC_ROOT/scripts/fuzz.log)',
    required=False,
    default=LOG_FILE
  )
  parser.add_argument(
    '-p',
    action='store_true',
    help='print statistics about seeds & payloads.'
  )

  args = parser.parse_args()

  print_payloads = args.p
  log_file = args.l

  with open(log_file, 'r') as f:
    lines = {i: line for i, line in enumerate(f.readlines())}

  copy_lines = (cp_line for cp_line in lines.values() if COPY_RE.match(cp_line))
  payload_map = {SEED_RE.findall(line)[0]: PL_RE.findall(line)[0] for line in copy_lines if line}

  attr_map = {}
  attr_map['useful'] = get_seeds_from_attribute(lines, USEFUL_RE)
  attr_map['useless'] = get_seeds_from_attribute(lines, USELESS_RE)
  attr_map['invalid'] = get_seeds_from_attribute(lines, INVALID_RE)

  if print_payloads:
    print_payload_stats(payload_map, attr_map)
  else:
    print_seed_stats(attr_map)