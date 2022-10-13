#!/bin/bash

##
# Find & print occurences of IO Read/Write functions in given directory.
#
# @param search_dir	The directory where the search should be conducted
##


find_occurences() {
	search_dir=$1
	fname=$2
	find $search_dir -name "*.h" -exec grep "^[[:alnum:]]*${fname}[[:alnum:]]*" {} \; | tr -d ' (' | sort -r | uniq
}

print_if_output() {
	to_print=$1
	output=$2
	if [ -n "$output" ]
	then
		echo "$to_print"
		echo "$output"
		echo
	fi
}



### MAIN ###

search_dir="./kafl.edk2"
[[ -n "$1" ]] && search_dir=$1

for component in 'Cr' 'Msr' 'Mmio' 'Pio' 'PciIo' 'VirtIo'
do
	echo "### ${component} ###"
	for action in 'Read' 'Write'
	do
		fname1="${action}${component}"
		find_occurences $search_dir $fname1

		fname2="${component}${action}"
		find_occurences $search_dir $fname2
	done
	echo
done