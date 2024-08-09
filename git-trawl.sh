#!/bin/bash

# this script originally based on one in comments from:
#  https://stackoverflow.com/questions/12850030/git-getting-all-previous-version-of-a-specific-file-folder
#  ...but almost entirely rewritten to my scripting style

# we'll write all git versions of the file to this folder, relative to PWD
tgtdir=_raw

# relative (to $PWD) path for the file to export
GIT_PATH_TO_FILE=$1

USAGE="Please cd to the root of your git proj and specify path to file you with to export (example: $0 some/path/to/file)"

# check if got argument
if [ -z "${GIT_PATH_TO_FILE}" ]; then
    echo "!! ERROR: no arguments given. 

    ${USAGE}" >&2
    exit 1
fi

# check if file exist
# TODO: consider if I need this check? I may want to extract files that no longer exist in the current version of the repo?!
if [ ! -f ${GIT_PATH_TO_FILE} ]; then
    echo "!! ERROR: File '${GIT_PATH_TO_FILE}' does not exist. 

    ${USAGE}" >&2
    exit 2
fi

######################################## pre-flight checks have passed

# filename only for target writing
GIT_SHORT_FILENAME=$(basename $GIT_PATH_TO_FILE)

# create folder to store all revisions of the file
mkdir -p ${tgtdir}

## uncomment next line to clear export folder each time you run script
#rm ${tgtdir}/*

# iterate the log entries which reference this file
    # TODO: test this with spaces in path/filenames
    # TODO: test to discover how it handles renamed files 
    #   (note: I think it should find them, but the pre-rename wont be reflected in exported filenames)
while read COMMIT_DATE COMMIT_HASH ; do 
    # we trust that the git and grep feeding this subshell did as expected
    tgtfile="${tgtdir}/${COMMIT_DATE}.${COMMIT_HASH}.${GIT_SHORT_FILENAME}"
    # intended file contents from the relevant commit
    git cat-file -p ${COMMIT_HASH}:${GIT_PATH_TO_FILE} > "${tgtfile}"
    # and touch to suit too
    touch -d "$COMMIT_DATE" "${tgtfile}"
    count=$((count+1))
done < <(git log --no-color --name-status --pretty='%aI %h' --all -- "${GIT_PATH_TO_FILE}" | grep -v "${GIT_PATH_TO_FILE}" | grep .)  

# return success code
echo "${count} result stored to ${tgtdir}"
exit 0
