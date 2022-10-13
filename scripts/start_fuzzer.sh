#!/bin/bash

# fixate the command with which the fuzzer is started for ease of use & reproducibility

# global vars
sdir=~/tdx/seeds
ip0=ffffffff81000000-ffffffff83603000
ip1=ffffffff86725000-ffffffff86802000


# write some sample seeds into seed dir
seeds () {
    mkdir $sdir 2> /dev/null
    echo "0123456789abcdef" > $sdir/seed_00000
}


# regular fuzzer
fuzz () {
    ./fuzz.sh run linux-guest \
        --purge \
        --seed-dir $sdir \
        -t 2 -ts 1 \
        -p 1 \
        -ip0 $ip0 -ip1 $ip1 \
        --log-hprintf \
        --trace
}

# coverage fuzzer picking up on previous work
cov () {
    ./fuzz.sh cov linux-guest \
        --resume \
        -t 2 \
        -p 1 \
        -ip0 $ip0 -ip1 $ip1 \
        --log-hprintf \
        --debug \
        --trace
}


while getopts 'fcs' OPTION; do
    case "$OPTION" in
        f)
            fuzz
            ;;
        c)
            cov
            ;;
        s)
            seeds
            ;;
        *)
            echo 'specify whether to fuzz regular or with coverage.'
            ;;
    esac
done
        

