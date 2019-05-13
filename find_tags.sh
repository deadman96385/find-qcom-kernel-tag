#!/usr/bin/env bash
# ^ the above shebang is preferred for portability between distros since bash
# isn't always installed at /bin and env has a higher probability of being
# located at /usr/bin across other distros than bash being found at /bin
# This script requires bash 4.4+

### Don't change anything below this line unless you know what you are doing.

tags_file="$(pwd)/tags.txt"
out_file="report.txt"
temp_changed_file="$(pwd)/temp_changes.txt"
temp_tag_file="$(pwd)/temp_tags.txt"
caf_url="https://source.codeaurora.org/quic/la/kernel/msm"

N=1 # DEFAULT for -j|--jobs and can be overwritten from commandline

# Colors for script
#BOLD="\033[1m"
GRN="\033[01;32m"
RED="\033[01;31m"
RST="\033[0m"
YLW="\033[01;33m"

# https://github.com/pollev/bash_progress_bar/blob/c2c8312d8d6fb4f2f1693a524c0942e34439215b/progress_bar.sh#L14-#L22
# Constants for progress bar
CODE_SAVE_CURSOR="\033[s"
CODE_RESTORE_CURSOR="\033[u"
CODE_CURSOR_IN_SCROLL_AREA="\033[1A"
COLOR_FG="\e[31m" # Foreground Red color
COLOR_BG="\e[40m" # Background Black color
RESTORE_FG="\e[39m" # Default foreground color
RESTORE_BG="\e[49m" # Default background color

# Alias for echo to handle escape codes like colors
# https://github.com/android-linux-stable/script/blob/9236762b163b3ae8ac78d6f5187c8b61a4184377/linux-stable.sh#L29-#L32
function echo() {
    command echo -e "$@"
}

function echoNew() {
    command echo -ne "$@"
}

# Prints a formatted header to point out what is being done to the user
# https://github.com/android-linux-stable/script/blob/9236762b163b3ae8ac78d6f5187c8b61a4184377/linux-stable.sh#L35-#L49
function header() {
    if [[ -n "${2}" ]]; then
        COLOR="${2}"
    else
        COLOR="${RED}"
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
    mapfile -t kv < <(grep -E 'VERSION|PATCHLEVEL' <(head -n 3 "${REPO_DIR}"/Makefile) | grep -Eo '[0-9][0-9]*')
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
#
# NOTE: This isn't needed any longer, but lets keep it around since it is
# harmless, and will provide extra protection.
function fixNewLine() {
    cat <<< "$(<"${tags_file}")" > "./temp.txt"
    cat <<< "$(<./temp.txt)" > "${tags_file}"
    rm ./temp.txt
}

function getParallelJobs () {
    # Get number of current runnning jobs.
    jobs -lpr >/dev/null
    jobs -lpr | wc -l
}

function checkParallelRestrictedJobs () {
    # Wait for the number of running jobs to be reduced
    # then start a new job when there is room available.
    if (( "${1}" <= $(getParallelJobs) )); then
        wait -n # Wait for 'a' job to finish
    fi
}

# https://github.com/pollev/bash_progress_bar/blob/c2c8312d8d6fb4f2f1693a524c0942e34439215b/progress_bar.sh#L29-#L51
function setupScrollArea() {
    # We will want to activate it whenever we setup the scroll area and remove
    # it when we break the scroll area.
    trapOnInterrupt

    lines=$(tput lines)
    lines=$((lines - 1))
    # Scroll down a bit to avoid visual glitch when the screen area shrinks by
    # one row.
    echoNew "\n"

    # Save cursor
    echoNew "${CODE_SAVE_CURSOR}"
    # Set scroll region (this will place the cursor in the top left)
    echoNew "\033[0;${lines}r"

    # Restore cursor but ensure its inside the scrolling area
    echoNew "${CODE_RESTORE_CURSOR}"
    echoNew "${CODE_CURSOR_IN_SCROLL_AREA}"

    # Start empty progress bar
    drawProgressBar 0
}

# https://github.com/pollev/bash_progress_bar/blob/c2c8312d8d6fb4f2f1693a524c0942e34439215b/progress_bar.sh#L53-#L74
function destroyScrollArea() {
    lines=$(tput lines)
    # Save cursor
    echoNew "${CODE_SAVE_CURSOR}"
    # Set scroll region (this will place the cursor in the top left)
    echoNew "\033[0;${lines}r"

    # Restore cursor but ensure its inside the scrolling area
    echoNew "${CODE_RESTORE_CURSOR}"
    echoNew "${CODE_CURSOR_IN_SCROLL_AREA}"

    # We are done so clear the scroll bar
    clearProgressBar

    # Scroll down a bit to avoid visual glitch when the screen area grows by one row
    echoNew "\n\n"

    # Once the scroll area is cleared, we want to remove any trap previously set.
    # Otherwise, ctrl+c will exit our shell.
    trap - INT
}

# https://github.com/pollev/bash_progress_bar/blob/c2c8312d8d6fb4f2f1693a524c0942e34439215b/progress_bar.sh#L157-#L161
function trapOnInterrupt() {
    # If this function is called, we setup an interrupt handler to cleanup the progress bar
    trap cleanupOnInterrupt INT
}

# https://github.com/pollev/bash_progress_bar/blob/c2c8312d8d6fb4f2f1693a524c0942e34439215b/progress_bar.sh#L163-#L166
# Clean up scroll area and temp files if the script is interrupted such as ctrl+c
function cleanupOnInterrupt() {
    destroyScrollArea
    # Clean up temp files
    rm -rf "${temp_dir}" 2> /dev/null
    rm "${temp_changed_file}" 2> /dev/null
    rm "${temp_tag_file}" 2> /dev/null
    exit
}

# https://github.com/pollev/bash_progress_bar/blob/c2c8312d8d6fb4f2f1693a524c0942e34439215b/progress_bar.sh#L76-#L95
function drawProgressBar() {
    percentage="${1}"
    lines=$(tput lines)
    lines="${lines}"
    # Save cursor
    echoNew "${CODE_SAVE_CURSOR}"

    # Move cursor position to last row
    echoNew "\033[${lines};0f"

    # Clear progress bar
    tput el

    # Draw progress bar
    printBarText "${percentage}"

    # Restore cursor position
    echoNew "${CODE_RESTORE_CURSOR}"
}

# https://github.com/pollev/bash_progress_bar/blob/c2c8312d8d6fb4f2f1693a524c0942e34439215b/progress_bar.sh#L118-#L132
function clearProgressBar() {
    lines=$(tput lines)
    lines="${lines}"
    # Save cursor
    echoNew "${CODE_SAVE_CURSOR}"

    # Move cursor position to last row
    echoNew "\033[${lines};0f"

    # clear progress bar
    tput el

    # Restore cursor position
    echoNew "${CODE_RESTORE_CURSOR}"
}

# https://github.com/pollev/bash_progress_bar/blob/c2c8312d8d6fb4f2f1693a524c0942e34439215b/progress_bar.sh#L134-#L151
function printBarText() {
    percentage="${1}"
    cols=$(tput cols)
    bar_size=$((cols - 18))

    color="${COLOR_FG}${COLOR_BG}"

    # Prepare progress bar
    complete_size=$(((bar_size * percentage ) / 100))
    remainder_size=$((bar_size - complete_size))
    progress_bar=$(
    echoNew "[";
    echoNew "${color}";
    printf_new "#" ${complete_size};
    echoNew "${RESTORE_FG}${RESTORE_BG}";
    if [[ "${percent}" -lt "100" ]]; then
        printf_new "." "${remainder_size}";
    else
        echoNew "${color}";
        printf_new "#" "${remainder_size}";
        echoNew "${RESTORE_FG}${RESTORE_BG}";
    fi;
    echoNew "]"
    );

    # Print progress bar
    echoNew " Progress ${percentage}% ${progress_bar}"
}

# https://github.com/pollev/bash_progress_bar/blob/c2c8312d8d6fb4f2f1693a524c0942e34439215b/progress_bar.sh#L168-#L173
function printf_new() {
    str="${1}"
    num="${2}"
    v=$(printf "%-${num}s" "${str}")
    echoNew "${v// /$str}"
}

# Variable is used in subshells and ultimately lost.
# Call this function to write the value to a temp file to save it.
function hackOldResult() {
    echo "${1}" > "${temp_changed_file}"
}

# Variable is used in subshells and ultimately lost.
# Call this function to write the value to a temp file to save it.
function hackBestTag() {
    echo "${1}" > "${temp_tag_file}"
}

# Prints information on how to use the script.
function usage() {
    cat <<EOF

USAGE: $0 [options]

OPTIONS:

  -h, --help
    Display this usage message and exit.

  -k <path>, --kernel <path>, --kernel=<path>
    Target kernel source at the root.

  -t <regex>, --tags <regex>, --tags=<regex>
    Populate tags.txt with a list from CAF.

  -j <N>, --jobs <N>, --jobs=<N>
    Run script with N processes. [optional]

EOF
}

# Logging and error handling functions for usage option commands.
function log() { echo ""; echo "$*"; }
function error() { log "${RED}ERROR: $*${RST}" >&2; }
function fatal() { error "$*"; exit 1; }
function usageFatal() { error "$*"; usage >&2; exit 1; }

# Parse non positional options
while [ "$#" -gt 0 ]; do
    arg="${1}"
    case "${1}" in
        # Convert "--opt=the value" to --opt "the value".
        # The quotes around the equals sign is to work around a
        # bug in emacs' syntax parsing.
        --*'='*) shift; set -- "${arg%%=*}" "${arg#*=}" "$@"; continue;;
        -j|--jobs) shift; N="${1}";;
        -k|--kernel) shift; REPO_DIR="${1}";;
        -t|--tags) shift; GIT_TAGS="${1}";;
        -h|--help) usage; exit 0;;
        -*) usageFatal "unknown option: '$1'";;
        *) usageFatal "unknown option: '$1'";;
    esac
    shift || usageFatal "option '${arg}' requires a value"
done

# If the kernel source isn't specified with -k|--kernel, then abort.
if [[ -z "${REPO_DIR}" ]]; then
    echo ""
    echo "${RED}Invalid kernel source location specified! Folder does not exist.${RST}"
    usage
    exit 0
fi

# If -k|--kernel is specified, check to see if Makefile exists as a way to validate
# that the path is correct.
if [[ ! -f ${REPO_DIR}/Makefile ]]; then
    echo ""
    echo "${RED}Invalid kernel source location specified! No Makefile present.${RST}"
    usage
    exit 0
fi

# Check if the path of the kernel source has a trailing forward slash and
# remove it if it does to prevent issues.
if echo "${REPO_DIR}" | grep -o /$ >/dev/null 2>&1; then
    REPO_DIR="${REPO_DIR%?}"
fi

# Check if tags is set after being specified with -t|--tags, and abort if not.
if [[ -z "${GIT_TAGS}" ]]; then
    echo ""
    echo "${RED}No specific points referenced in a repository's history! No tag present.${RST}"
    usage
    exit 0
fi

# Check if the specified tag returns true, or we need to abort, then report
# that the regex is invalid and to try again.
if [ -n "$(git -C "${REPO_DIR}" tag -l "${GIT_TAGS}")" ]; then
    # We need to populate tags.txt so lets do it as specified by -t|--tags.
    git -C "${REPO_DIR}" tag -l "${GIT_TAGS}" > "${tags_file}"
else
    echo ""
    echo "${RED}'${GIT_TAGS}' is invalid and does not exist! Try again.${RST}"
    usage
    exit 0
fi

# Let's kick off some sanity checks before starting the main labor of this script
getKernelVersion
checkGitRemote
fetchGitRemote
fixNewLine

process_count="0" # This is primarily for parallel jobs but can be used either way.
carriage="\r"
trail_nl="n"
count_base="0"
count_index=$(wc -l < "${tags_file}")
clear # Clean up any junk on the screen
header "Find-Qcom-Kernel-Tag"
setupScrollArea # Create initial progress bar for staging

# Create a temp directory to isolate the temp files created during the loop
temp_dir="$(pwd)/${RANDOM}_temp"
mkdir -p "${temp_dir}"
echo "999999999" > "${temp_changed_file}" # Temp file for changed results in diffed files

while IFS= read -r tag; do
    process_count=$((process_count + 1)) # Temp file extensions
    count_base=$((count_base + 1)) # Progress bar
    percent=$((count_base * 100 / count_index)) # Progress bar

    # Generate progress bar as script moves forward
    drawProgressBar "${percent}"

    {
        tag_hash=$(git -C "${REPO_DIR}" show -s --format=%H "${tag}" | tail -n1)
        git -C "${REPO_DIR}" fetch "${caf_remote}" "${tag_hash}" >> /dev/null 2>&1
        git -c diff.renameLimit=9999 -C "${REPO_DIR}" diff "${tag_hash}" --shortstat > "${temp_dir}"/"${out_file}"-"${process_count}"
        mapfile -t result < <(echo grep -Eo '[0-9][0-9]* files changed' | grep -Eo '[0-9][0-9]*' "${temp_dir}"/"${out_file}"-"${process_count}")
        if [ "${count_base}" == "${count_index}" ]; then
            carriage=""
            trail_nl=""
        fi

        # Need to make sure the array, $result, isn't empty or it will report an
        # error expecting an integer expression.
        if (( ${#result[@]} )); then
            if [ "${result[0]}" -le "$(cat "${temp_changed_file}")" ]; then
                hackOldResult "${result[0]}"
                hackBestTag "${tag}"
                echo -${trail_nl}e "  ${YLW}New best tag:     ${tag}, files changed: ${result[0]}${RST}  ${carriage}"
            else
                old_result=$(<"${temp_changed_file}")
                best_tag=$(<"${temp_tag_file}")
                echo -${trail_nl}e "  ${GRN}Current best tag: ${best_tag}, files changed: ${old_result}${RST}  ${carriage}"
            fi
        else
            old_result=$(<"${temp_changed_file}")
            best_tag=$(<"${temp_tag_file}")
            echo -${trail_nl}e "  ${GRN}Current best tag: ${best_tag}, files changed: ${old_result}${RST}  ${carriage}"
        fi
    } & # This ampersand will run it in the background

    # Allow only to execute $N jobs in parallel if -j|--jobs was used.
    # Put on queue until a job has finished and opens up another slot
    # for another job.
    if [[ -n "${N}" ]]; then
        checkParallelRestrictedJobs "${N}"
    else
        # Kill the script and clean up.
        # N must return a value to prevent an infinite loop.
        cleanupOnInterrupt
    fi

done < <(grep -v '^ *#' < "${tags_file}") # Process substitution
wait # Wait for pending jobs

# Cleanup leftover files
rm -rf "${temp_dir}" 2> /dev/null && rm "${temp_changed_file}" 2> /dev/null && rm "${temp_tag_file}" 2> /dev/null
destroyScrollArea # Remove progress bar

# Before finishing up, let the user know how to remove the caf remote at their
# own discretion when they are ready.
echo ""
echo "To save space you can now remove the caf remote when you are ready."
echo "Manually remove the caf remote with command: ${RED}git remote rm ${caf_remote}${RST}"
echo ""
