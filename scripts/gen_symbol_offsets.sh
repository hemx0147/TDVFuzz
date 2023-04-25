#!/bin/bash

##
# Print a mapping of TDVF modules loaded in a kAFL/Qemu session to their
# corresponding memory offsets.
#
# Usage: gen_symbol_offsets.sh [OPTIONS]
#
# Options:
#   -h, --help      display this help text
#   -l LOGFILE      Use a TDVF log file LOGFILE containing addresses of modules loaded
#                   in the Qemu session (default: KAFL_WORKDIR/hprintf_00.log)
#   -b BUILDDIR     Path to the EDK2/TDVF Build directory (default: TDVF_ROOT/Build)
#   -s [NAME]       Write output to a GDB script file with name NAME (default: gdbscript)
#   -v              print verbose output
##
# Information about loaded modules is provided by a log file containing
# TDVF debug prints.
#
# If the log file option (-l) is not specified, the script will only print
# offsets of the SecMain module.
#
# The output can be provided as a GDB script that, if executed in GDB,
# will automatically import debug symbols for all modules loaded in the
# Qemu session.
#
# This script uses the peinfo tool available at https://github.com/retrage/peinfo.
##


####################################
# Global Variables
####################################
BUILD_DIR=$(realpath "$TDVF_ROOT/Build")
SEARCH_DIR="$BUILD_DIR/OvmfX64/DEBUG_GCC5/X64"
PEINFO=$(realpath "$PEINFO_ROOT/peinfo")
SCRIPT_NAME="gdbscript"
LOGFILE=$(realpath "$KAFL_WORKDIR/hprintf_00.log")
PRINT_SCRIPT=0
HAVE_LOG=0
VERBOSE=0

####################################
# Function Definitions
####################################

# print script usage information given above in comments
function usage()
{
	# find usage line
    usage_start=$(grep -n "^# Usage" "$0" | awk -F ":" '{print $1}')
    # print only usage part
    tail -n +"$usage_start" "$0" | sed -ne '/^#/!q;/^##/q;s/.\{1,2\}//;p'
    exit
}

# print help text given above in comments
function help()
{
	# find usage line
    help_start="`grep -n "^##" "$0" | head -n 1 | awk -F ":" '{print $1}'`"
    # print only usage part
    tail -n +"$help_start" "$0" | sed -ne '/^#/!q;s/.\{1,2\}//;1d;p'
    exit
}

# exit with errorcode 1 & print usage
function fatal()
{
    [[ -n "$1" ]] && echo "Error: $1"; echo
    usage >&2
    exit 1
}

# only print if VERBOSE flag is set
function verbose_print()
{
  [[ $VERBOSE -eq 1 ]] && echo "$1"
}

# print module + memory address; prepend "add-symbol-file" if output should be script
function print()
{
  MODULE_NAME="$1"
  MODULE_ADDR="$2"
  DEBUG_FILE="$3"

  if [[ $PRINT_SCRIPT -eq 1 ]]
  then
    verbose_print "saving results in $SCRIPT_NAME."
    echo "add-symbol-file $DEBUG_FILE $MODULE_ADDR" >> $SCRIPT_NAME
  else
    echo "$MODULE_NAME $MODULE_ADDR"
  fi
}

# find symbols for SecMain module (always included but not part of debug log)
function print_secmain_symbols()
{
  DEBUG_FILE="SecMain.debug"
  FILE_BASENAME="SecMain"

  verbose_print "searching symbols for module ${FILE_BASENAME}..."

  SEC_MAP="`find $BUILD_DIR -type f -name 'SECFV.Fv.map'`"
  [[ -z ${SEC_MAP} ]] && fatal "Could not find SECFV map file in build directory. Consider rebuilding TDVF."

  verbose_print "found $SEC_MAP"

  TEXT="`grep -oE '.textbaseaddress=0x[0-9a-fA-F]{1,16}' $SEC_MAP | awk -F '=' '{print $2}'`"
  SYMFILE="`find ${SEARCH_DIR} -maxdepth 1 -type f -name ${DEBUG_FILE}`"
  if [[ -z ${SYMFILE} ]]
  then
    # SecMain debug file may exist only in module directory
    EFIFILE="`find ${SEARCH_DIR} -type f -name ${DEBUG_FILE} | grep ${FILE_BASENAME}/DEBUG/${DEBUG_FILE}`"
  fi
  [[ -z ${SYMFILE} ]] && fatal "Could not find ${FILE_BASENAME} debug file in build directory. Consider rebuilding TDVF."

  # print module + memory address
  print "${FILE_BASENAME}" "${TEXT}" "${SYMFILE}"
}

# find memory addresses for other modules
function print_module_symbols()
{
  LOG="$1"
  cat ${LOG} | grep Loading | grep -i efi | while read LINE; do
    MEM_BASE="`echo ${LINE} | cut -d " " -f4`"
    FILE_NAME="`echo ${LINE} | cut -d " " -f6 | tr -d "[:cntrl:]"`"
    FILE_BASENAME=$(echo ${FILE_NAME} | sed -e "s/.efi$//")

    verbose_print "searching symbols for module ${FILE_BASENAME}..."
    [[ $FILE_BASENAME == "HelloWorld" ]] && continue

    EFIFILE="`find ${SEARCH_DIR} -maxdepth 1 -type f -name ${FILE_NAME}`"
    if [[ -z ${EFIFILE} ]]
    then
      # some .efi files exist in nested directories only
      EFIFILE="`find ${SEARCH_DIR} -type f -name ${FILE_NAME} | grep ${FILE_BASENAME}/DEBUG/${FILE_NAME}`"
    fi

    [[ -z ${EFIFILE} ]] && fatal "Could not find .efi file for module ${FILE_BASENAME}"

    ADDR="`${PEINFO} ${EFIFILE} | grep -A 5 text | grep VirtualAddress | cut -d ' ' -f2`"
    TEXT="`python -c "print(hex(${MEM_BASE} + ${ADDR}))"`"
    SYMS="`echo ${FILE_NAME} | sed -e "s/\.efi/\.debug/g"`"
    SYMFILE="`find ${SEARCH_DIR} -name ${SYMS} -type f -maxdepth 1`"
    if [[ -z ${SYMFILE} ]]
    then
      # some .debug files exist in nested directories only
      SYMFILE="`find ${SEARCH_DIR} -name ${SYMS} -type f | grep ${FILE_BASENAME}/DEBUG/${SYMS}`"
    fi

    print "${FILE_BASENAME}" "${TEXT}" "${SYMFILE}"
  done
}



####################################
# Main()
####################################

# argument parsing
# note: options can be given multiple times,
#       i.e. "script -n 5 -n 10" executes func_with_args once with 5 and once with 10
POSITIONAL_ARGS=()
while [[ "$#" -gt 0 ]]
do
	case "$1" in
        '-h'|'--help')
            help
            ;;
        '-l')
            LOGFILE=$(realpath "$2")
            HAVE_LOG=1
            shift   # past value
            shift   # past argument
            ;;
        '-b')
            [[ -z "$2" ]] && fatal "Missing parameter PATH"
            BUILD_DIR=$(realpath "$2")
            SEARCH_DIR="$BUILD_DIR/OvmfX64/DEBUG_GCC5/X64"
            shift   # past argument
            shift   # past value
            ;;
        '-s')
            if [[ "$2" != -* ]]
            then
              [[ -n "$2" ]] && SCRIPT_NAME="$2"
              shift   # past value
            fi
            PRINT_SCRIPT=1
            shift   # past argument
            ;;
        '-v')
            VERBOSE=1
            shift   # past argument
            ;;
        -*|--*)
            fatal "Unknown option $1"
            ;;
        *)
            POSITIONAL_ARGS+=("$1") # save positional arg
            shift   # past argument
            ;;
    esac
done
set -- "${POSITIONAL_ARGS[@]}"  # restore positional parameters


[[ -d "$BUILD_DIR" ]] || fatal "invalid path to build directory \"$BUILD_DIR\""
echo $BUILD_DIR

# if output should be saved in script: delete old script file if it exists
[[ $PRINT_SCRIPT -eq 1 ]] && [[ -f $SCRIPT_NAME ]] && rm $SCRIPT_NAME

# symbols for SecMain should always be included
print_secmain_symbols

# find memory addresses for other modules
if [[ $HAVE_LOG -eq 1 ]]
then
  [[ -f $LOGFILE ]] && print_module_symbols $LOGFILE || fatal "log file $LOGFILE does not exist"
fi

# add command to automatically connect to waiting fuzzer debug process
[[ $PRINT_SCRIPT -eq 1 ]] && echo "target remote localhost:1234" >> $SCRIPT_NAME