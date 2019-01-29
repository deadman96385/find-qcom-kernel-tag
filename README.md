# Script to find the base kernel tag for a kernel source

I will say first and formost this is not a great script, but it works for what i need.

Steps to use it

1. Download your devices kernel source with no edits from you
2. Add a branch pointing at the caf msm-3.4/msm-3.10/msm-3.18/msm-4.4/etc kernel like this https://source.codeaurora.org/quic/la/kernel/msm-3.10/
3. Run ```git fetch -all```
4. One folder up from your kernel source put the find_tag.sh and the tags.txt
5. In the find_tag.sh edit the repo dir to point at yours
6. To generate the tags.txt either manually put your tags in or do a command like this to get it be sure to change the regex part to match your kernel  ```git -C ${REPO_DIR} ls-remote --tags caf '*LA\.BR\.*8x16*[0-9]' | sed s'/[ \t]\+/ /'g | cut -d' ' -f2```
7. Run the script and wait for it to finish to tell you the best tag.
8. Enjoy
