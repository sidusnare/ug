ug
==

UG the UGly script to Upgrade Gentoo


Parts
===
There are two scripts, ug.sh and lug.sh. lug is the Lightweight version of ug. I run ug once weekly and lug daily.

Intro
===
This script started out as a brute force script to upgrade Gentoo. It has evolved into a script I run from cron daily to perform continuous integration of the Gentoo Linux distribution.

Method
===
The idea is to get a perfectly integrated system, or as close to it as reasonable, as you can on a constant basis. I would not recommend this for production systems. Perhaps a golden image creator for production systems in a continuous integration / development environment. I use it on my personal systems, and it works well for me, but I know there have been changes in Gentoo in the past that would not have gracefully applied through this script.

Notes
===
This may also be a good general guideline for someone who hasn't upgraded Gentoo before, but can read my horrible scripting, as the order of operations and general content of upgrading Gentoo.

This program takes no arguments and is to be run as root.

It is designed to be brief enough to put in a cron job and let the output be mailed to you. To this end, it has eselect news, glsa-check, and emerge -p output but other activity it logged into /var/log/ug and rotated on a weekly basis.

I used to keep /boot mounted ro and had this script re-mount it rw and then back. I have opted to not do this any more, and instead have it mounted with the sync option. In the post LILO / GRUB ecosystem I belive this is just as safe. If you do not, you will need to adjust for it, as packages that need to write to /boot will fail, such as genkernel and GRUB.

Requirements
===
- Gentoo
- Bravery
- app-portage/gentoolkit
- sys-devel/gcc-config
- app-admin/python-updater
- app-admin/perl-cleaner
- sys-apps/grep
