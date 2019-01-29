#!/bin/bash

tags_file="tags.txt"
out_file="report.txt"
REPO_DIR="android_kernel_lenovo_msm8909/"

old_result=999999999

for tag in `cat ${tags_file}`; do
	tag_hash=`git -C ${REPO_DIR} sh -s --format=%H ${tag} | tail -n1`
	git -C ${REPO_DIR} fetch caf ${tag_hash} >> /dev/null 2>&1
	git -c diff.renameLimit=9999 -C ${REPO_DIR} diff ${tag_hash} --shortstat >> ${out_file}
	result=`echo egrep -o '[0-9][0-9]* files changed'|egrep -o '[0-9][0-9]*' report.txt| dd status=none bs=1 count=5`
	rm ${out_file}
	if [ "$result" -le "$old_result" ]; then
		old_result=$result
		best_tag=${tag}
		echo -e "New best tag:     ${tag}, files changed: ${result}"
	else
		echo -e "Current best tag: ${best_tag}, files changed: ${old_result}"
	fi

done
