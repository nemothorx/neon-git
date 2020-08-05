# git-timemachine

Set the time of your git commits. This is intended for turning a directory
of script archives into a git repo, and maintain appropriate timing metadata

The script outputs GIT_AUTHOR_DATE and GIT_COMMITTER_DATE environment lines
as per https://alexpeattie.com/blog/working-with-dates-in-git/

These lines can then be copypasta as required to the local shell. 

Heavy git users may enjoy an alias to turn "git-timemachine" into "git timemachine"

$ git config --global alias.timemachine '!git-timemachine $3'

For scripted use, the output can be processed automatically by `eval`
$ eval `git timemachine [file|string]`

Note: I have chosen to use echo/eval rather than "source" so the default
running of the script is informative. 

# ARG1 options
* path/to/file - and get it's mtime
* string - parse it as a datetime string with date(1) unless one of:
  * "status" - display our times
  * "now|return" - unset our variables
* no ARG1 - prompt within the script for either of the above
  ...if still nothing, then unset our variables


# NOTES/BUGS
* Using "eval" method without a param will silently prompt for input, and then silently fail regardless of input.
* Filenames take precedence over other interpretations of the input string
  * Thus it's impossible to use "status" "now" or "return" if a file by that
    name exists in the PWD. Workaround: Change PWD first
