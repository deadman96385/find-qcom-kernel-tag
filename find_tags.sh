#!/bin/bash

tags_file="tags.txt"
out_file="report.txt"
REPO_DIR="android_kernel_lenovo_msm8909/"

old_result=999999999

grep -v '^ *#' < "${tags_file}" | while IFS= read -r tag; do
	tag_hash=$(git -C "${REPO_DIR}" show -s --format=%H "${tag}" | tail -n1)
	git -C "${REPO_DIR}" fetch caf "${tag_hash}" >> /dev/null 2>&1
	git -c diff.renameLimit=9999 -C "${REPO_DIR}" diff "${tag_hash}" --shortstat >> "${out_file}"
	mapfile -t result < <(echo grep -Eo '[0-9][0-9]* files changed' | grep -Eo '[0-9][0-9]*' report.txt)
	rm "${out_file}"
	if [ "${result[0]}" -le "$old_result" ]; then
		old_result="${result[0]}"
		best_tag="${tag}"
		echo -e "New best tag:     ${tag}, files changed: ${result[0]}"
	else
		echo -e "Current best tag: ${best_tag}, files changed: ${old_result}"
	fi

done
