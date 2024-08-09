#!/bin/bash

# TL;DR doco: usage like so:
#
#   git commit -m "$(git-automsg.sh)"
# or
#   git commit -m "$(git-automsg.sh "My own commit message")"


# The idea here is to generate an informative commit message suitable
# for autocommit setups, and better than a generic "this is an ato commit"
#
# It attempts to merge the best bits of 
#   git status  
# and
#   git diff --stat
#
# ...it does this by doing a "git diff --compact-summary" 
#    and then recreating the "git status" info with some simple sed

# BUGS and LIMITATIONS
# * Filenames that mimic the output of `git diff --compact-summary` in part or whole will break things in unpredictable ways
#
# TODO and WISHLIST
# * I'd like the "(+x)" and similar to be right-aligned
# * if git natively provided a merged diff summary and status like here,
#   and so made this script redundant, that'd be great!

# git compactsummary is our core info. Run `git` once for this
git_cs=$(git diff ^HEAD --compact-summary --stat=64)

# If it's empty, then we silently bail as nothing had changed.
# If we're run within `git -m "$(git-automsg.sh)"` then the parent git will
# also fail to commit without a message. 
[ -z "$git_cs" ] && exit

# Grab the summary of the summary from the last line
git_cs_summary=$(echo "$git_cs" | tail -n 1)

# generate a compactsummary/status mashup from the rest
git_cs_status="$(echo "$git_cs" | grep '|' | sed -e '
    s/^/modified: /g ;
    s/modified: \(.*\) (new)\( *| .*\)/new file: \1 \2/g ;
    s/modified: \(.*\) (new \(.*) *| .*\)/new file: \1 (\2/g ;
    s/modified: \(.*\) (mode \(.*) *| .*\)/modified: \1 (\2/g ;
    s/modified: \(.*\) (gone)\( *| .*\)/deleted:  \1 \2/g ;
    s/modified: \(.*\) => \(.*\)/renamed:  \1 => \2/g;
    s/ *|/\t|/g' | column -t -s'	' )"
# sed logic: any file listed is assumed to be "modified", then alternatives
# (new/deleted/renamed are identified and added in and other formatting tweaked


# Now the final output

# If we're given a msg then it goes first and summary last (matching original
# `git diff --stat` style). Otherwise summaryline goes first
# 
# note that "$@" can be multiline, and should flow into the git log correctly
if [ -n "$1" ] ; then
    finalmsg="$@

$git_cs_status
$git_cs_summary"
else
    finalmsg="$git_cs_summary

$git_cs_status"
fi

# The true output is the finalmsg we made all along
echo "$finalmsg"
