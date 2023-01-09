#!/bin/bash

# Create reports from assertions in all hprintf log files in LOG_DIR directory
# An assertion report contains Module, file, line no. & violated condition of the triggered assertion
#
# Usage: gen_assert_report.sh LOG_DIR

LOG_DIR="$1"

ASSERTS="ASSERT.*/OvmfPkg"
grep $ASSERTS $LOG_DIR/hprintf_??.log | sort | uniq | awk '{$1=""; print $0}'