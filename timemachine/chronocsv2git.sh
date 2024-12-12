#!/bin/bash

# Usage: $0 [-p]
#   -p = prompt before processing each line from the source csv
#
# This script complements git-timemachine by processing a CSV (character
# seperated, where character is bash IFS - ie, space/tab) containing the
# following format
# 
# src_filename tgt_filename commit message(which, may be\n\n"complex"))
# $ ls -r -o -t
#
# * note1: headerless CSV
# * note2: if field 1 is "$" then field2 is a command and field3+ are options
# * note2: lines beginning with '#' are ignored as comments. Blank lines also
#          ignored
# * note3: if there is only fields 1,2 and no commit message, then there is no
#          git commit against that file. git add only. Thus multiple files may
#          be added prior to a single commit
# 
# The commit message itself is interpreted through `echo -e` thus while it's
# a single line in the CSV, it can output to multiple lines. Note the
# double-escape though:
# filename_v1 filename first "version"\\n\\nthis is seriously old. 
#
# The benefit of all this is that preparing the csv then running this script
# should be easier than preparing a custom import2git.sh as per example at
# https://github.com/nemothorx/indexpage/commit/0ca47029637fc5ec21c20a6c46765169f71a4f02
#
# The actual purpose is for importing into git a collection of
# found-from-backups (or similar) old versions of a single script which have
# been given ad-hoc names but have era-accurate timestamps. Eg:
# -rw-r--r-- 1 nemo 3.3K Sep 20  2003 runranplay_1.0
# -rw-r--r-- 1 nemo 3.5K Sep 30  2003 runranplay_1.0_
# -rw-r--r-- 1 nemo 5.4K Jul 14  2004 runranplay_1.2_Myk
# -rw-r--r-- 1 nemo 4.6K Mar 22  2005 runranplay_1.2
# -rw-r--r-- 1 nemo 4.6K Jul 11  2005 runranplay_1.2_
# -rw-r--r-- 1 nemo 7.4K Oct 16  2012 runranplay_1.9
# -rw-r--r-- 1 nemo 7.6K Jun 13  2020 runranplay_1.10
# -rw-r--r-- 1 nemo 7.6K Mar 30  2021 runranplay_1.10_
# -rw-r--r-- 1 nemo 7.7K Sep  9  2021 runranplay_1.11
# -rw-r--r-- 1 nemo 7.7K Apr 24 18:14 runranplay_1.11_

# HOW IT WORKS
# The script will process chronogit.csv line by line, cp -a each source_filename
# to the target_filename, then git add it. 
# If there is a 'msg', then git-timemachine sets the timing from the file, 
# and then commits with that msg. 
# 
# WHAT IT DOES NOT DO DIRECTLY
# * does not create the git repo itself
#   * because this is tested, it cannot even be a sub-command in chronogit.csv
# * nor does it do any complex branching, merging, etc.
#   * ie, it's intended for a catchup of a single file from historic archives
#     into git, whilst maintaining date metadata. Nothing more. 
# * however, it DOES support arbitrary sub-commands via "$" directive in the
#   csv. Through that, git checkout, branching, etc, can all be added in

# Colours:
BOLD=$(tput bold)       # for errors causing exit
REV=$(tput rev)         # for showing the line being processed when prompting
RED=$(tput setaf 1)     # for errors causing exit
TEAL=$(tput setaf 6)    # for announcing cp+git implied commands from the csv
GRN=$(tput setaf 2)     # for announcing explicit commands from the csv
YLW=$(tput setaf 3)     # showing the explicit command requested
                            # also: info about errors causing exit
                            # also: user explicit command todo at end
PURPLE=$(tput setaf 5)  # for headings from chronocsv2git 
                            # also: prompts (in bold)
WHITE=$(tput setaf 7)
RESET=$(tput sgr0)      # output of git commands

############################################ MAIN

ctrlfile=chronogit    # this is a prefix. actual files have csv or md suffix

case $1 in
    -p) prompt=true ;;
esac

if [ ! -e $ctrlfile.csv ] ; then
    echo "${RED}${BOLD}! no csvfile found (expecting $ctrlfile.csv))${RESET}
${YLW}Please read the comments in the source for $0 for format of csv
    - by convention, chronogit.csv
    - it will generate a chronogit.md to suit
For now however: Exiting with nothing to do${RESET}"
    exit 1
fi

if [ ! -d ".git" ] ; then
    echo "${RED}${BOLD}! Not yet a git repo. I dont do that step. please fix (git init ?)${RESET}"
    exit 2
fi


#### pass 1:  sanity check csvfile
# ensure all col1 exist as files or commands
# TODO: ensure all col1 files have a filename in col2 also
# and all col3 are non-zero

echo "${PURPLE}## Testing uniqueness of source files${RESET}"
srcfileinfo=$(cat $ctrlfile.csv | grep -v '^#' | grep -v '^\$' | grep . | cut -d" " -f 1 | sort | uniq -d -c)
[ ! -z "$srcfileinfo" ] && echo "${RED}${BOLD}! non-unique source file(s) found${RESET}" && echo "$YELLOW$srcfileinfo${RESET}" && exit 3


echo "${PURPLE}## Testing all targets are commands or non-existent files${RESET}"
while read srcfile tgtfile msg ; do
    case $srcfile in
        "$")
            if  ! command -v "$tgtfile" &>/dev/null ; then
                echo "${RED}${BOLD}! command $tgtfile could not be found. Fix pls${RESET}"
                exit 4
            fi
            ;;
        *)
            [ ! -e "$srcfile" ] && echo "${RED}${BOLD}! src $srcfile not found. Fix $ctrlfile.csv${RESET}" && exit 5
            [ -z "$tgtfile" ] && echo "${RED}${BOLD}! $srcfile has no target. Bailing now${RESET}" && exit 6
            [ -e "$tgtfile" ] && echo "${RED}${BOLD}! $tgtfile already exists. Refusing to blat it with $srcfile. pls fix${RESET}" && exit 7
            ;;
    esac
done < <(cat $ctrlfile.csv | grep -v '^#' | grep . )

echo""

# TODO: validate $msg to be suitable for "$msg" in git commandline. ie, no '"'??

#### preparation: capture state of everything right now. 
[ -e $ctrlfile.md ] && echo "${BOLD}${PURPLE}note: $ctrlfile.md already exists. I will overwrite in 3 seconds... (^c to quit)${RESET}" && sleep 5
echo "
This commit of this repo was generated by chronocsv2git.sh (part of
git-timemachine) with data from $ctrlfile.csv

Details of files as they existed at time of running script:
(via \`ls -rotR --full-time\`)
" >> $ctrlfile.md
ls -rotR --full-time >> $ctrlfile.md

git add $ctrlfile.csv
git add $ctrlfile.md
git commit -a -m "$(git-automsg.sh "chronocsv2git begin: adding chronogit.csv and chronogit.md")"
echo ""


#### pass 2: do the git-thing

while read -u 3 srcfile tgtfile msg ; do
    if [ -n "$prompt" ] ; then
        read -p "${BOLD}${PURPLE}:: [enter] to process the following line:${RESET}
${REV}${GRN}$srcfile${WHITE} -> ${TEAL}$tgtfile
${YLW}$msg${RESET} " proceed
    fi
    case $srcfile in
        "$")
            echo "${GRN}:: cmd: '${YLW}$tgtfile $msg${RESET}${GRN}'${RESET}"
            echo -e $tgtfile $msg | bash   # this is how we get params handled right
                # note: "tgtfile" here is really a command
                # and "msg" will be params to that command
            echo ""
            ;;
        *)
            echo "${TEAL}:: cp+git add: ${YLW}$(cp -av $srcfile $tgtfile)${RESET}"
            git add $tgtfile
            if [ -n "$msg" ] ; then
                eval $(git timemachine $tgtfile) # set the time of commit
                commitmsg=$(echo -e "${msg}") # msg from the chronogit.csv
                finalmsg="$(git-automsg.sh "$commitmsg")" # git-automsg adds statistics to the msg
                git commit -a -m "$finalmsg"
                echo ""
            fi
            ;;
    esac
done 3< <(cat $ctrlfile.csv | grep -v '^#' | grep .)

echo ""
echo ""

srcflist=$(cat $ctrlfile.csv | cut -d" " -f 1 | grep -v '^\$' | grep -v '^\#' | grep . | tr "\n" " ")
echo "${PURPLE}## Your todo: manual review/cleanup:
${BOLD}* review git log. If satisfied then remove original source files${RESET}"
echo "${BOLD}${YLW}tar cvfz chronogitcsv2git-timemachine.tgz $ctrlfile.csv $ctrlfile.md $srcflist
rm $srcflist
git rm $ctrlfile.csv
git rm $ctrlfile.md${RESET}"
echo "${BOLD}${PURPLE}* Update README.md to suit

$RESET${PURPLE}...over to you!${RESET}"
