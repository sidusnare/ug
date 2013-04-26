#!/bin/bash

################################################################################
#UG the UGly script to Upgrade Gentoo
###
#This is not a good script to upgrade Gentoo quickly or properly
#This is a script to run in a for look a few (10-20) times while your not planning on using your computer for a few days, perhaps you have something better to do with your weekend than Gentoo
#The idea is to clear all use, keyword, and distfile issues with `emereg -u --deep --newuse -v --tree world -p` and then run ug a few times, maybe go to work/school for the day.
#Then you come home, sort out what its choked on and run it a few more times.
#rinse, later, repeat
###
#This may also be a good general guideline for someone who hasn't upgraded Gentoo before, but can read my horrible bash scripting, as the order of operations and general content of upgrading Gentoo.
###
#This program takes no arguments and is to be run as root, perhaps in /root/, or some other nice place you don't mind me making some files.
###
#Requirements:
#dev-util/lafilefixer
#app-portage/gentoolkit
#sys-devel/gcc-config
#app-admin/python-updater
#app-admin/perl-cleaner
################################################################################

function reld {
	env-update
	source /etc/profile
	ldconfig

	env-update
	source /etc/profile
	ldconfig


}
[ -d /var/log/ug ] || mkdir -p /var/log/ug

##########
#Build list
##########

#er log sucsess here
touch ug.good
#We need a temporary file, take care not to step on toes
pkglist="$TMP"/"$RANDOM"
while [ -e "$pkglist" ]; do
	pkglist="$TMP"/"$RANDOM""$RANDOM"
done

echo "Searching for packages to upgrade"
EMERGE_DEFAULT_OPTS="--autounmask=y" /usr/bin/emerge -u --nospin --deep --newuse -v --color n world -p --columns | grep -v ^$ | grep '^\[' | cut -c  18- | awk '{print($1)}' > $pkglist 2>> /dev/null
echo "There are `wc -l $pkglist` packages to upgrade"

cat /var/lib/portage/world >> $pkglist
echo "There are `wc -l /var/lib/portage/world` packages in world"

#Need another temporary file, take care not to step on toes
tmp2="$TMP"/"$RANDOM"
while [ -e "$tmp2" ];do
	tmp2="$TMP"/"$RANDOM""$RANDOM"
done

#remove duplicates
cat $pkglist | sort -u > $tmp2
cat $tmp2 > $pkglist

echo "There are `wc -l ug.good` packages that have already been upgraded"
#remove sucsesfully upgrades atoms from list, remember we dumped world into the list.
for x in `cat ug.good`;do
	cat $pkglist | grep -v ^$x$ > $tmp2
	cat $tmp2 > $pkglist
	echo -n \.
done
echo

echo "There are `wc -l $pkglist` total packages to do upgrade runs for"
#Loop over list

##########
#Upgrade pass
##########

#Loop ofer the list
for x in `cat $pkglist`; do 
	echo -e "\n\n\t\tEmergeing $x for upgrade run\n"
	#for the log files
	ln=`echo $x | tr '/' '_'`
	#Upgrade it, first pass with --deep --newuse
	emerge --deep --newuse -u $x 2>> /var/log/ug/$ln.err.log >> /var/log/ug/$ln.log 
	ret=$?
	if [ "$ret" -lt 1 ];then
		echo "sucsess in deep $x with $ret"
		echo $x >> ug.good
	else
		echo $x >> ug.dfail
		echo "failure in deep $x with $ret"
		#If that didnt work, try without --deep --newuse, and if something changes underneath we (probably) will catch it on the revdep-rebuild run
		emerge -u $x 2>> /var/log/ug/$ln.err.log >> /var/log/ug/$ln.log && echo "sucsess in shallow $x " || (echo "failure in shallow $x "; echo $x >> ug.sfail)
	fi
	reld
done
##########
#Prune pass
##########
#Prune old stuff we dont need
echo -e "\n\n\tPruning old stuff:\n"
pl=`equery -C -q   list --format='$cp' "*" | sort | uniq -c | sort -n | sed -e 's/^  *//g' | grep -v ^1 | awk '{print($2)}'`

echo -e "\n\n\tRunning prune:\n"
	for x in $pl;do
		echo -e "\n\n\tEmerging $x for prune\n"
		cn=`echo $x | tr '/' '_'`
		emerge --prune -v $x 2>> /var/log/ug/purge.$cn.err.log >> /var/log/ug/purge.$cn.log && echo "sucsess in $x " || echo "failure in $x "
	done
#Sometimes we prune the active GCC compiler, oops! Better set it again.
gcc-config $(gcc-config -l | grep `uname -m` | awk '{print($2)}')
##########
#RevDep rebuild pass
##########

#Clean up old runs of revdep-rebuild
echo -e "\n\n\tCleaning revdep-rebuild\n"
	rm -f /var/cache/revdep-rebuild/* >> /dev/null 2>> /dev/null
	rm -f /tmp/revdep-rebuild.*/* >> /dev/null 2>> /dev/null
#Run revdep-rebuild in pretend mode to generate a list for us to loop over, done want to tap out on the first little problem
echo -e "\n\n\tRunning revdep-rebuild:\n"
	revdep-rebuild -p >> /dev/null 2>> /dev/null
	echo -e "\n\n\t\tEmerging revdep-rebuild packages:\n\n"
	if [ -e  /var/cache/revdep-rebuild/4_ebuilds.rr ] ; then
		for x in `cat /var/cache/revdep-rebuild/4_ebuilds.rr | awk -F : '{print($1)}'`; do 
			echo -e "\n\n\t\tEmergeing $x for revdep rebuild:\n"
			emerge -1 $x >> /var/log/ug/rr.log 2>> /var/log/ug/rr.err.log 
			reld
		done
	else
		echo revdep-rebuild didnt create package list
	fi

##########
#Perl cleaner
##########
#Clean up our perl
echo -e "\n\n\tRunning Perl cleaner:\n"
	perl-cleaner all >> /var/log/ug/pc.log 2>> /var/log/ug/pc.err.log
	reld

##########
#Python updater
##########
#update our python
echo -e "\n\n\tRunning python updater:\n"
	python-updater -p > /var/log/ug/pu.pkgl.dirty
	cat /var/log/ug/pu.pkgl.dirty | grep keep-going | tr ' ' '\n' | awk -F : '{print($1)}' | sort | uniq | egrep -v 'Dv1$|keep-going$|\*$|^emerge$|^$|^-p$' > /var/log/ug/pu.pkgl
	rm /var/log/ug/pu.pkgl.dirty
	echo -e "\n\n\t\tEmerging python updater list\n\n"
		for x in `cat /var/log/ug/pu.pkgl`;do 
		echo -e "\n\n\tEmerging $x for python updater:\n"
		emerge -1 $x >> /var/log/ug/pu.log 2>> /var/log/ug/pu.err.log;
		reld
	done

##########
#la file fixer
##########
#This might not be needed anymore, but whatever.
echo -e "\n\n\tRunning lafilefixer:\n"
	lafilefixer --justfixit >> /var/log/ug/la.log 2>> /var/log/ug/la.err.log
	reld

reld
rm $tmp2 $pkglist
