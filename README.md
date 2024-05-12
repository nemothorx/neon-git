# git-timemachine

A set of tools to help turn a directory of script archives into a git repo, and
maintain appropriate timing metadata

So far, two tools:

* `git-timemachine`
* `chronocsv2git.sh`


## git-timemachine

This script outputs GIT_AUTHOR_DATE and GIT_COMMITTER_DATE environment lines as
per https://alexpeattie.com/blog/working-with-dates-in-git/

These lines can then be copypasta as required to the local shell. 

Heavy git users may enjoy an alias to turn "git-timemachine" into "git
timemachine"

> `git config --global alias.timemachine '!git-timemachine $3'`

For scripted use, the output can be processed automatically by `eval`

> `eval $(git timemachine [file|string])`

Note: I have chosen to use echo/eval rather than "source" so the default
running of the script is informative. 


### Example of use

* First dozen or so commits (2005-2020) in
  https://github.com/nemothorx/indexpage
  * Added via this script:
    https://github.com/nemothorx/indexpage/commit/0ca47029637fc5ec21c20a6c46765169f71a4f02


### ARG1 options
* path/to/file - and get it's mtime
* string - parse it as a datetime string with date(1) unless one of:
  * "status" - display our times
  * "now|return|reset" - unset our variables
* no ARG1 - prompt within the script for either of the above
  ...if still nothing, then unset our variables


### NOTES/BUGS
* Using "eval" method without a param will silently prompt for input, and then
  silently fail regardless of input.
* Filenames take precedence over other interpretations of the input string
  * Thus it's impossible to use "status" "now" "return" or "reset" if a file by
    that name exists in the PWD. 
    * Workaround: change to a different directory before running those


## chronocsv2git.sh

**NOTE: chronocsv2.git is not considered finished. Use at own risk**

A script which takes a prepared csv for a directory of historic files, and
controls git-timemachine in adding them to a repo with suitable dates. 

Usage is simply `chronocsv2git.sh`. 



## ghls

With this, this repo is moving away from being git timemachine specific tools,
and starting to be my personalised set of git tools of any form. 

ghls is a "github ls". On a normal directory it runs "ls" with suitable options
to give a listing identical to github. In a git repo, it gives commit info per
file and directory, mimicking the github interface. 


## _gitconfig

My depersonalised gitconfig. Mainly here for the aliases. Some are practical,
some fun. (`git lg1` is my musclememory replacement for `git log`)

