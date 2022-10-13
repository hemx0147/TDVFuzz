#!/bin/bash

# Obtain uniqe assertion reports from all hprintf logs in current directory
# An assertion report contains the Module, file, line no & violated condition of the triggered assertion

OUTDIR=~/tdvf-hello
OUTFILE=assertions_unique.txt

ASSERTS="ASSERT.*/home/ryannick/tdx/kafl/edk\.git/OvmfPkg"
grep $ASSERTS hprintf_??.log | sort | uniq | awk '{$1=""; print $0}' > $OUTDIR/$OUTFILE