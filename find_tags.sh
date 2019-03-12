#!/bin/bash

### User should change REPO_DIR according to the root path of their source tree.
REPO_DIR="android_kernel_lenovo_msm8909/"

### Don't change anything below this line unless you know what you are doing.
tags_file="tags.txt"
out_file="report.txt"
caf_url="https://source.codeaurora.org/quic/la/kernel/msm"

old_result=999999999

# Colors for script
BOLD="\033[1m"
GRN="\033[01;32m"
RED="\033[01;31m"
RST="\033[0m"
YLW="\033[01;33m"

# Alias for echo to handle escape codes like colors
# https://github.com/android-linux-stable/script/blob/master/linux-stable.sh#L29-#L32
function echo() {
    command echo -e "$@"
}

# Prints a formatted header to point out what is being done to the user
# https://github.com/android-linux-stable/script/blob/master/linux-stable.sh#L35-#L49
function header() {
    if [[ -n ${2} ]]; then
        COLOR=${2}
    else
        COLOR=${RED}
    fi
    echo "${COLOR}"
    # shellcheck disable=SC2034
    echo "====$(for i in $(seq ${#1}); do echo "=\c"; done)===="
    echo "==  ${1}  =="
    # shellcheck disable=SC2034
    echo "====$(for i in $(seq ${#1}); do echo "=\c"; done)===="
    echo "${RST}"
}

function getKernelVersion() {
    # Makefile can be located at the root of the kernel source and it already
    # tells us what the kernelversion is. We can automatically grab this information
    # without requiring user interaction then use that for caf.
    mapfile -t kv < <(grep -E 'VERSION|PATCHLEVEL' <(head -n 3 "${REPO_DIR}"Makefile) | grep -Eo '[0-9][0-9]*')
    kernel_version="${kv[0]}.${kv[1]}"
}

function checkGitRemote() {
    if git -C "${REPO_DIR}" remote -v | grep -E "${caf_url}-${kernel_version}" >> /dev/null 2>&1; then
        # Remote for caf already exists so use theirs instead of creating a new remote
        # The remote should be pure and untouched, and I can't think of any reason
        # as to why it wouldn't be. TODO: Maybe add a condition statement to verify
        # if the remote is clean or polluted and handle it accordingly?
        mapfile -t gr < <(git -C "${REPO_DIR}" remote -v | grep -E "${caf_url}-${kernel_version}" | awk '{print $1}')
        caf_remote="${gr[0]}"
    else
        # Missing remote for caf so lets create one and make sure the remote name
        # doesn't already exist. We will attempt to use fqkt in this instance, but
        # should it exist, then we will amend a $RANDOM value.
        # fqkt is short for find-qcom-kernel-tag.
        caf_remote="fqkt"
        if git -C "${REPO_DIR}" config remote."${caf_remote}".url; then
            caf_remote="fqkt-${RANDOM}"
        fi
        git -C "${REPO_DIR}" remote add "${caf_remote}" "${caf_url}"-"${kernel_version}"
    fi
}

function fetchGitRemote() {
    header "Fetching Remote: ${caf_remote}"
    # Fetch/update remote
    git -C "${REPO_DIR}" fetch "${caf_remote}"
}

# There are many ways for someone to populate the tags file. Some methods will
# create a newline at the end of the file which is what we need since we rely on
# wc to give an accurate count. Since the opposite effect can happen we need to
# check and insure this newline even exists and if it doesn't then create one.
# Additionally, we want to insure there are not multiple inclusions of newlines
# at the end of the file so using cat to recreate the tags file will resolve all
# problems without hassle.
function fixNewLine() {
    cat <<< "$(<${tags_file})" > "./temp.txt"
    cat <<< "$(<./temp.txt)" > "${tags_file}"
    rm ./temp.txt
}

# Let's kick off some sanity checks before starting the main labor of this script
getKernelVersion
checkGitRemote
fetchGitRemote
fixNewLine

carriage="\r"
trail_nl="n"
count_base="0"
count_index=$(wc -l < "${tags_file}")
clear # Clean up any junk on the screen
header "Find-Qcom-Kernel-Tag"
grep -v '^ *#' < "${tags_file}" | while IFS= read -r tag; do
    count_base=$((count_base + 1))
    percent=$((count_base * 100 / count_index))
    tag_hash=$(git -C "${REPO_DIR}" show -s --format=%H "${tag}" | tail -n1)
    git -C "${REPO_DIR}" fetch "${caf_remote}" "${tag_hash}" >> /dev/null 2>&1
    git -c diff.renameLimit=9999 -C "${REPO_DIR}" diff "${tag_hash}" --shortstat >> "${out_file}"
    mapfile -t result < <(command echo grep -Eo '[0-9][0-9]* files changed' | grep -Eo '[0-9][0-9]*' report.txt)
    rm "${out_file}"
    if [ "${count_base}" == "${count_index}" ]; then
        carriage=""
        trail_nl=""
    fi
    # Need to make sure the array, $result, isn't empty or it will report an
    # error expecting an integer expression.
    if (( ${#result[@]} )); then
        if [ "${result[0]}" -le "${old_result}" ]; then
            old_result="${result[0]}"
            best_tag="${tag}"
            command echo -${trail_nl}e "  ${YLW}New best tag:     ${tag}, files changed: ${result[0]}  ${BOLD}${RED}(${RST}Progress: ${percent}%${RED})${RST}${carriage}"
        else
            command echo -${trail_nl}e "  ${GRN}Current best tag: ${best_tag}, files changed: ${old_result}  ${BOLD}${RED}(${RST}Progress: ${percent}%${RED})${RST}${carriage}"
        fi
    else
        command echo -${trail_nl}e "  ${GRN}Current best tag: ${best_tag}, files changed: ${old_result}  ${BOLD}${RED}(${RST}Progress: ${percent}%${RED})${RST}${carriage}"
    fi

done

# Before finishing up, let the user know how to remove the caf remote at their
# own discretion when they are ready.
echo ""
echo "To save space you can now remove the caf remote when you are ready."
echo "Manually remove the caf remote with command: ${RED}git remote rm ${caf_remote}${RST}"
echo ""
