ug
==

UG the UGly script to Upgrade Gentoo


Intro
===
This is not a good script to upgrade Gentoo quickly or properly.
This is a script to run in a for loop a few (10-20) times while your not planning on using your computer for a few days, perhaps you have something better to do with your weekend than Gentoo.
Method
===
The idea is to clear all use, keyword, and distfile issues with `emereg -u --deep --newuse -v --tree world -p` and then run ug a few times, maybe go to work/school for the day.
Then you come home, sort out what its choked on and run it a few more times.
Rinse, later, repeat.
Notes
===
This may also be a good general guideline for someone who hasn't upgraded Gentoo before, but can read my horrible bash scripting, as the order of operations and general content of upgrading Gentoo.

This program takes no arguments and is to be run as root, perhaps in /root/, or some other nice place you don't mind me making some files.

Requirements
===
-app-portage/gentoolkit
-sys-devel/gcc-config
-app-admin/python-updater
-app-admin/perl-cleaner


