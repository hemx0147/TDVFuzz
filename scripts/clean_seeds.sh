#!/bin/env bash

# Script for reducing number of fuzzing seeds.
#
# This script runs the fuzzer once and runs the show_seed_stats python script to detect invalid/useless seeds.
# It then attempts to remove these seeds from the seed directory after asking user for consent.
#
# Since the fuzzer copies files from the seed directory into its /import dir under a new name,
# this script requires the fuzzer to print out the source and destination names of the copied seeds.


SEEDS_DIR="$BKC_ROOT/sharedir"
SCRIPTS_DIR="$BKC_ROOT/scripts"
LOG_FILE="$KAFL_WORKDIR/kafl_fuzzer.log"
FUZZ_SCRIPT=$SCRIPTS_DIR/build-n-fuzz.sh
SEED_INFO_SCRIPT=$SCRIPTS_DIR/show_seed_stats.py


# exit with errorcode 1
# optional argument: print error message.
function fatal()
{
  [[ -n "$1" ]] && echo "Error: $1"; echo
  exit 1
}

function clean_and_exit()
{
  # delete temporary log file
  rm $LOG_FILE > /dev/null
  exit $1
}


### Main ###
[[ -d $SCRIPTS_DIR ]] || fatal "no such file or directory \"$SCRIPTS_DIR\""
[[ -d $SEEDS_DIR ]] || fatal "no such file or directory \"$SEEDS_DIR\""
[[ -f $FUZZ_SCRIPT ]] || fatal "no such file or directory \"$FUZZ_SCRIPT\""
[[ -f $SEED_INFO_SCRIPT ]] || fatal "no such file or directory \"$SEED_INFO_SCRIPT\""

# run fuzzer once and create log file with info about copied seeds
$FUZZ_SCRIPT -v
[[ -f $LOG_FILE ]] || fatal "no such file or directory \"$LOG_FILE\""
SEED_INFO=$(grep -E "copying .* -> seed_[0-9]+" $LOG_FILE)
if [[ -z $SEED_INFO ]]
then
  echo "no information about input seeds found. Make sure to provide a seeds directory to fuzzer and that fuzzer prints source/dest names of copied seeds."
  clean_and_exit 1
fi

# find payloads of useless/invalid seeds
BAD_PAYLOADS=$(python $SEED_INFO_SCRIPT -l $LOG_FILE -p | grep -E "invalid|useless")
if [[ -z "$BAD_PAYLOADS" ]]
then
  echo "no useless/invalid payloads found."
  clean_and_exit 0
fi

# remove bad payloads if user confirms
echo "$BAD_PAYLOADS"
read -p "delete useless/invalid payloads? (Y/N): " confirm && [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]] || clean_and_exit 1
echo "$BAD_PAYLOADS" | awk -v seed_dir=$SEEDS_DIR '{print seed_dir"/"$2}' | xargs rm
clean_and_exit 0