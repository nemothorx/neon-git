#!/bin/bash

# sometimes I find it convenient to have filesystem timestamps be accurate to the last time the file was touched by human hands, not git checkouts. 
#
# This script will touch(1) each file given as a param, to the time of it's most recent git entry

while [ -e "$1" ] ; do
    tgttime=$(git log -1 --date=iso-strict --pretty=format:"%ad" "$1")
    [ -z "$tgttime" ] && touch -d "$tgttime" "$1"
    shift
done
