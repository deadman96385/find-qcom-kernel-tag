# Script to find the base kernel tag for a kernel source

I will say first and foremost this is not a great script, but it works for what I need.

Steps to use it

1. Download your devices kernel source with no edits from you.
2. One folder up from your kernel source put the find_tag.sh and the tags.txt.
3. In the find_tag.sh edit the repo dir to point at yours.
4. To generate the tags.txt either manually put your tags in or do a command like this to get it be sure to change the regex part to match your kernel  ```git -C ${REPO_DIR} tag -l LA.BR.*8x16*```.
5. Run the script and wait for it to finish to tell you the best tag.
6. Enjoy.
