#!/bin/bash

# create a calender of commit activity over time, similar to github.
# ...this may be worth rolling into ghls?
#
# name based on https://github.com/k4rthik/git-cal
# (found when seeing if there were existing solutions)
# no code reuse though

# a note on PERFORMANCE
# This script basically does two things:
# 1. `git log`
# 2. parse the results.
#
# For a 17 month history, parsing takes approx 2.5 seconds on my system
# The overall performance then is dependant on git log
# ...on a repo with approx a dozen commits, `git log` is effectively instant, and overall duration of ~2.5 seconds.
# ...on a repo with 2.7million commits in 17 months (linux kernel), `git log` takes approx 3 seconds, for an overall duration of 5.5 seconds.
#

# example intended output using these potential characters
# c for character
c="■"  #    25A0    BLACK SQUARE
c="◼"  #    25FC    BLACK MEDIUM SQUARE
c="▩"  #    25A9    SQUARE WITH DIAGONAL CROSSHATCH FILL
c="▣"  #    25A3    WHITE SQUARE CONTAINING BLACK SMALL SQUARE
c="▪"  #    25AA    BLACK SMALL SQUARE
c="▮"  #    25AE    BLACK VERTICAL RECTANGLE
c="⧯"  #    29EF    ERROR-BARRED BLACK SQUARE
c="🮋"  #    1FB8B   RIGHT SEVEN EIGHTHS BLOCK
c="█"  #    2589    FULL BLOCK
c="▒"  #    2592    MEDIUM SHADE
c="▓"  #    2593    DARK SHADE

# this works on macOS, but I'd have to invert fg/bg everywhere to have it do the "1st = underline" that the "upper seven eighths block" does. overline doesn't look right visually
c="▇"  #    2587    LOWER SEVEN EIGHTHS BLOCK

# this has the same problem as the lower seven eights block. It reads as a marker for the character to the right, not the left
c="▉"  #    2589    LEFT SEVEN EIGHTHS BLOCK

# this is my second fave, also fails on macOS 15.6.1
c="🮆"  #    1FB86   UPPER SEVEN EIGHTHS BLOCK

# this is my fave visually, but fails on macOS 15.6.1
c="🭌"  #    1FB4C   LOWER LEFT BLOCK DIAGONAL UPPER CENTRE TO UPPER MIDDLE RIGHT


# 3 columns on left (border, weekdays, border)
# 1 column on right (border)
# Thus 80column term can handle 76 weeks, or 75 FULL weeks, thus X column term we set for x-5 weeks back in history)
# note:
# 52 weeks = year(ish)
# 65 weeks = 1.25 years
# 70 weeks = 1.3333 years
# 75 weeks is roughly 17 months

# If you want more history, make your terminal wider!
# TODO: consider a -y option to do a year, "-y x" to do multiple - in exact year blocks

# note: I start weeks on monday (ISO8601), rather than sunday-first as gh uses

# questions n answers
# Timezones?
    # No. I'm lazy. Git commits store the timezone of the original commit, so I just count commits per-day from the point of view of the day the committer commited them
    # I believe this means it's technically possible for an Australian to make a commit to a repo, and a few hours LATER, a californian to make a commit, but the californian commit show up on this graph on the PREVIOUS day.
    # ...this COULD be normalised by getting all logs in unix time, but I dont care that much.
    # Plus, I dont think the current behaviour is nescessarily a bug. It's indicative of the day of commit according to the commiter.
# Filter per user, or exclude some branches
    # Nope. But theoretically doable if you know your `git log` command sufficiently.

runat_t=$(date +%s)

###### functions

do_setcol() {
    val=$1
    # set the colour based on $val
    [ -z "$val" ] && col=$col0 && return # nonexistent=zero. nothing more to test
    [ "$val" = 0 ] && col=$col0 && return # zero, nothing more to test

    [ "$val" -ge 1 ] && col=$col1 # >0 so set to 1st quartile and keep testing
    [ "$val" -gt "$(($peak/4))" ] && col=$col2  # more than top of 1st quartile
    [ "$val" -gt "$(($peak/2))" ] && col=$col3 # more than top of the second
    [ "$val" -gt "$((3*$peak/4))" ] && col=$col4  # more than top of third
}


###### main

# find our starting monday
columns=$(tput cols)
weeks=$(($columns-5))    # we have room for this many full weeks back

noontoday_t=$(date -d 12:00 +%s)  # time_t for noon today (avoid DST edge cases when walking days later in the code)

# 86400 is seconds in a day,  604800 seconds in a week
weeksago_t=$(($noontoday_t - ($weeks*604800) ))  # time_t for our target weeks back

weeksago_day=$(date -d @$weeksago_t +%a)    # day of our target history

# and adjust backwards to monday:
case $weeksago_day in
    Mon) daysback=0 ;;
    Tue) daysback=1 ;;
    Wed) daysback=2 ;;
    Thu) daysback=3 ;;
    Fri) daysback=4 ;;
    Sat) daysback=5 ;;
    Sun) daysback=6 ;;
esac
startmonday_t=$(($weeksago_t - ($daysback*86400) ))

# setup our colours (gh style is shades of green: 28,34,40,46)
#       my style is blue/green/yellow/red as a more true "heat" of the map
#       white corners for 1st of month should also remain visible-ish
col0=$(tput setaf 236)  # usage =0
col1=$(tput setaf 33)   # usage = lowest quartile: 1-25%
col2=$(tput setaf 34)   # usage = second quartile: 26-50%
col3=$(tput setaf 178)   # usage = third  quartile: 51-75%
col4=$(tput setaf 196)   # usage = fourth quartile: 76-100%

# START OUTPUT
rset=$(tput sgr0 ; tput setab 0) # yes, forcing black background
echo "${rset}Commit heatmap calender - $weeks weeks (from $(date -d @$startmonday_t +"%a %d %b %Y")) $(tput el)"
    # TEMPLATE THE OUTPUT
echo "   "  # this line will be populated by month labels later on
echo " M "
echo "   "
echo " W "
echo "   "
echo " F "
echo "   "
echo " S "

tput cuu 7  # back up to monday row
tput cuf 3  # forward 3 columns

# now we've setup the basic shape first for a fast-apparent UI, let's get the data

# initialise some things
declare -A heatdata
peak=0
# get the data into that array
while read a b ; do
    [ -n "$b" ] && heatdata["${b}"]=$a  # handle a cal with zero data
    [ "$a" -gt "$peak" ] && peak=$a
done < <( (git log --since="$(($weeks+1)) weeks ago" --format=format:'%ad' --date=format:"%a %d %b %Y" ; echo ) | sort -k 4g -k 3M -k 2g | uniq -c )
    # weeks+1 because we have a fraction-of-a-week extra relative to $weeks
    # TODO: BUG? ...git log with --since can pull in things EARLIER than the since. I assume due to complications of branches and/or differnces between GIT_AUTHOR_DATE and GIT_COMMITTER_DATE.
    # ...I'm not git savvy enough to improve this (or say this is optimal)

# heatdata array is indexed in the form of a date. eg
# heatdata[Tue 10 Dec 2024]=2

# starting from $startmonday_t, get the date, check the heatdata, and print the character, and step forward a day
for t in $(seq ${startmonday_t} 86400 ${noontoday_t} ) ; do
    d=$(date -d @$t +"%a %d %b %Y")
    # if it's a new month, we should jump to the month line and print it, then return! wheeeeee!
    noyear=${d% *}
    month=${noyear##* }
    noday=${d#* }
    date=${noday%% *}
    if [ "$month" != "$monthprev" ] && [ $((t+604800)) -le $runat_t ] ; then
        # jump up and print the month label, then jump back
        # note: I dont do this in the last week, since if we're in the final COLUMN, it wraps the terminal
        # TODO: BUG: fix this so it only avoids if we're in the actual last column
        #   alt fix: reduce the number of rows done, and do a right-side MTWTFSS row key
        case $d in
            *Mon*) lines=1 ;;
            *Tue*) lines=2 ;;
            *Wed*) lines=3 ;;
            *Thu*) lines=4 ;;
            *Fri*) lines=5 ;;
            *Sat*) lines=6 ;;
            *Sun*) lines=7 ;;
        esac
        tput cuu $lines
        printf "${rset}${month}"
        tput cud $lines ; tput cub 3
    fi
    # 1st of the month = tag the corner to suit
    [ "$date" == "01" ] && tput setab 15 || tput setab 0
    monthprev=$month
    do_setcol ${heatdata["$d"]}
    printf ${col}${c}
    tput cud 1 ; tput cub 1
    case $d in
        *Sun*)  # After sunday, we back to the top
            tput cuu 7
            tput cuf 1
            ;;
    esac
done

# final summary
tput cud 7  # ensure we're at the end of the everything
tput cub $columns  # and at the start of line
# activity scale indicators (values same as do_setcol)
echo -n "    ${rset}Activity scale: "
echo -n "[0:${col0}${c}${rset}] "
echo -n "[1»$(($peak/4)):${col1}${c}${rset}] "
echo -n "[»$(($peak/2)):${col2}${c}${rset}] "
echo -n "[»$((3*$peak/4)):${col3}${c}${rset}] "
echo "[»$peak:${col4}${c}${rset}]"

