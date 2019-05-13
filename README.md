# Script to find the base kernel tag for a kernel source

Steps to use it

1. Download your devices kernel source with no edits from you.
2. Run the script, find_tags.sh, and tell it the root path of your kernel source
   and the tag regex you are targeting.
3. Wait for it to finish to tell you the best tag. [Optional] See the entire list
   of tags checked in file, tags.txt, which the script generates in the same path
   as where you run this script.
4. Enjoy.

[Optional]

The script offers support to run in parallel to speed up the process. This
performance will vary upon your systems specs. See, ./find_tags.sh -h, for usage.
-j|--jobs will default to running only 1 process unless otherwise specified.


Some examples for the script, targeting device platform msm8998:

    ./find_tags.sh -t *89xx* -k /path/to/kernel
	
    ./find_tags.sh -t LA.UM.*89xx* -k /path/to/kernel
	
    ./find_tags.sh --kernel=/path/to/kernel --tags=LA.UM.*89xx*
	
    ./find_tags.sh -t *89xx* -k /path/to/kernel -j 4
	
    ./find_tags.sh --kernel=/path/to/kernel --tags=LA.UM.*89xx* --jobs=4
	

NOTE: 

The script will verify if your tag regex returns true and is validated.
      If it returns false then the tag(s) you seek for do not exist and the script
      will abort giving you an error about your regex and to try again. It is
      the sole responsibility of the user to insure they know what tag(s) they
      seek for.
