#!/usr/bin/env bash

################################################################################
#UG the UGly script to Upgrade Gentoo
###
#Requirements:
#app-portage/gentoolkit
#sys-devel/gcc-config
#app-admin/python-updater
#app-admin/perl-cleaner
################################################################################



function reld {
	env-update  &>> /dev/null
	source /etc/profile &>> /dev/null
	ldconfig &>> /dev/null

	env-update &>> /dev/null
	source /etc/profile &>> /dev/null
	ldconfig &>> /dev/null


}

source /etc/profile
if [ ! -e /etc/portage ]; then
	echo 'This script is for Gentoo only, unable to find /etc/portage.' >&2
	exit 1
fi

if which rvm &>> /dev/null; then
	echo "Deactivating RVM"
        rvm use system
fi

source /etc/profile
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
if [ "$EUID" -gt 0 ];then
	echo "This script must be run as root" >&2
	exit 1
fi

if [ -z "$TMP" ]; then
	if [ -d /tmp ]; then
		export TMP=/tmp
	else
		echo Unable to find TMP 1>&2
		exit 1
	fi
fi
if [ ! -e /var/lib/ug ];then
	mkdir /var/lib/ug
fi
for prog in glsa-check emerge eselect perl-cleaner python-updater revdep-rebuild gcc-config equery egrep awk cut echo grep sort sed wc cat date;do
	if ! which "$prog" &>> /dev/null; then
		echo "Unable to find ${prog}, please install it and try again." >&2
		exit 1
	fi
done
if ! which cpuinfo2cpuflags-x86 &>> /dev/null; then
	emerge app-portage/cpuinfo2cpuflags &>> /dev/null
fi
if ! fgrep "$(cpuinfo2cpuflags-x86)" /etc/portage/make.conf &>> /dev/null;then
	cpuinfo2cpuflags-x86 >> /etc/portage/make.conf
fi

export DATE=$(date +%s)
#Only keep persistent working data and logs around 1 week, but keep last week's data around for reference
if [ $(find /var/lib/ug -xdev -name timer -mtime +5 2>> /dev/null | wc -l ) -gt 0 ] ; then
	if [ -e /var/lib/ug/old ]; then
		echo "Cleaning up last weeks data"
		rm -rf /var/lib/ug/old
	fi

	mv /var/lib/ug /var/lib/ug.old
	mv /var/log/ug /var/log/ug.old
	mkdir /var/lib/ug
	mkdir /var/log/ug
	mv /var/lib/ug.old /var/lib/ug/old
	mv /var/log/ug.old /var/log/ug/old
	
	touch /var/lib/ug/timer
fi
cd /var/lib/ug/
if [ ! -e /var/log/ug ];then
	mkdir /var/log/ug
fi

##########
#Build list
##########

#we log sucsess here
touch /var/lib/ug/ug.good

#We need a temporary file, take care not to step on toes
pkglist="/var/lib/ug/pkg_list"
tmp2="/var/lib/ug/tmp"
> /var/lib/ug/pkg_list
> /var/lib/ug/tmp
echo "Syncing"
rm -rf /usr/portage/.git*
emerge --sync -q &>> /dev/null
rm -rf /usr/portage/.git*
echo News
eselect news read all
eselect news purge &>> /dev/null

echo 'Security check'
#glsa-check -l -q -n | egrep -v '\[U\]|\[A\]'
glsa-check -l -q -n affected
#
#Start off with simple run, like "normal"
#
echo "Emerging world: "
emerge --deep --newuse -u world -p -v 
set -x

emerge --deep --newuse -u world &>> /var/log/ug/emerge.${DATE}.log ||\
emerge --deep -u world &>> /var/log/ug/emerge.${DATE}.log ||\
emerge --newuse -u world &>> /var/log/ug/emerge.${DATE}.log ||\
emerge -u world &>> /var/log/ug/emerge.${DATE}.log

set +x
echo "Searching for packages to upgrade"
#Upgrade world, with different premutations to get as complete a list as we can to itterate over
EMERGE_DEFAULT_OPTS="--autounmask=y" /usr/bin/emerge -u --nospin --deep --newuse -v --color n world -p --columns 2>> /dev/null |\
	grep -v ^$ | grep '^\[' | cut -c  18- | awk '{print($1)}' > /var/lib/ug/pkg_list
EMERGE_DEFAULT_OPTS="--autounmask=y" /usr/bin/emerge -u --nospin --newuse -v --color n world -p --columns 2>> /dev/null |\
	grep -v ^$ | grep '^\[' | cut -c  18- | awk '{print($1)}' >> /var/lib/ug/pkg_list
EMERGE_DEFAULT_OPTS="--autounmask=y" /usr/bin/emerge -u --nospin --deep -v --color n world -p --columns 2>> /dev/null |\
	grep -v ^$ | grep '^\[' | cut -c  18- | awk '{print($1)}' >> /var/lib/ug/pkg_list 
EMERGE_DEFAULT_OPTS="--autounmask=y" /usr/bin/emerge -u --nospin -v --color n world -p --columns 2>> /dev/null |\
	grep -v ^$ | grep '^\[' | cut -c  18- | awk '{print($1)}' >> /var/lib/ug/pkg_list 
EMERGE_DEFAULT_OPTS="--autounmask=y" /usr/bin/emerge @preserved-rebuild -u --nospin  -v --color n  -p --columns 2>> /dev/null |\
	grep -v ^$ | grep '^\[' | cut -c  18- | awk '{print($1)}' >> /var/lib/ug/pkg_list 2>> /dev/null
echo "There are $(wc -l /var/lib/ug/pkg_list) packages to upgrade"

#This is a bit much, but if you have frequent slot conflicts, uncomenting it may get you more complete.
#cat /var/lib/portage/world >> /var/lib/ug/pkg_list
#echo "There are $(wc -l /var/lib/portage/world) packages in world"
if [ -e /home/fred4/Documents/Tech/Package_Lists/gentoo/package_lists ]; then
	for pkg in `cat /home/fred4/Documents/Tech/Package_Lists/gentoo/package_lists/base`;do
		emerge -n "${pkg}"
	done
fi
#remove duplicates
sort -u < /var/lib/ug/pkg_list > /var/lib/ug/tmp
cat /var/lib/ug/tmp > /var/lib/ug/pkg_list

echo "There are $(wc -l /var/lib/ug/ug.good | awk '{print($1)}') packages that have already been upgraded."
#remove sucsesfully upgrades atoms from list
if [ -s /var/lib/ug/ug.good ]; then
	if [ -s "/var/lib/ug/pkg_list" ]; then
		egrep -v -f /var/lib/ug/ug.good /var/lib/ug/pkg_list > /var/lib/ug/tmp
		cat /var/lib/ug/tmp > /var/lib/ug/pkg_list
	fi
fi

echo "There are $(wc -l /var/lib/ug/pkg_list | awk '{print($1)}') total packages to do upgrade runs for"
#Loop over list

##########
#Upgrade pass
##########

#Loop over the list
for pkg in $(sort -R /var/lib/ug/pkg_list); do 
	echo -e -n "Emergeing ${pkg} for upgrade run..."
	#for the log files
	ln=$(echo "$pkg" | tr '/' '_')
	#Upgrade it, first pass with --deep --newuse
	emerge --deep --newuse -u "$pkg" &>> "/var/log/ug/${ln}.log"
	ret=$?
	if [ "$ret" -lt 1 ];then
		echo "...sucsess in deep ${pkg}."
		echo "$pkg" >> /var/lib/ug/ug.good
	else
		echo "$pkg" >> ug.dfail
		echo -n "...failure in deep , trying shalow..."
		#If that didnt work, try without --deep --newuse, and if something changes underneath we (probably) will catch it on the revdep-rebuild run
		emerge -u "$pkg" &>> "/var/log/ug/${ln}.log" &&\
		( echo "...sucsess in shallow."; echo "$pkg" >> ug.sgood ) ||\
		( echo "...failure in shallow."; echo "$pkg" >> ug.sfail )
	fi
	reld
	source /etc/profile

done
##########
#Prune pass
##########
#Prune old stuff we dont need, if you want to be careful, comment out this part and do it by hand.
echo -e "Pruning old stuff:"
pl=$(equery -C -q   list --format='$cp' "*" | sort | uniq -c | sort -n | sed -e 's/^  *//g' | grep -v ^1 | awk '{print($2)}')

echo -n "Pruning:"
for pkg in $pl;do
	echo -n "${pkg} "
	cn=$(echo "$pkg" | tr '/' '_')
	emerge --prune -v "$pkg"  &>> "/var/log/ug/purge.${cn}.log" && echo -n "+ " || echo -n "- "
done
echo -e "\nDone"
#Sometimes we prune the active GCC compiler, oops! Better set it again.
gcc-config $(gcc-config -l | grep $(uname -m) | awk '{print($2)}' | tail -n 1) &>> /dev/null

##########
#RevDep rebuild pass
##########

#Run revdep-rebuild in pretend mode to generate a list for us to loop over, dont want to tap out on the first little problem
echo -e "Running revdep-rebuild:"
	#Clean up old runs of revdep-rebuild
	rm -f /var/cache/revdep-rebuild/* &>> /dev/null
	rm -f /tmp/revdep-rebuild.*/* &>> /dev/null
	#Running pretend pass to generate files we will parse apart
	revdep-rebuild -p &>> /dev/null
	if [ -e  /var/cache/revdep-rebuild/4_ebuilds.rr ] ; then
		for pkg in $(cat /var/cache/revdep-rebuild/4_ebuilds.rr | awk -F : '{print($1)}'); do 
			ln=$(echo "$pkg" | tr '/' '_')
			echo -e "Emergeing ${pkg}"
			emerge -1 "$pkg" &>> "/var/log/ug/rr.${ln}.log"
			reld
			source /etc/profile
		done
	else
		echo "revdep-rebuild list empty"
	fi

##########
#Perl cleaner
##########
#Clean up our perl
echo -e "Running Perl cleaner:"
	> /var/lib/ug/pc.pkgl
	perl-cleaner --reallyall --pretend | grep ' emerge ' | tr ' ' '\n' | grep / &>> /var/lib/ug/pc.pkgl
	for pkg in $(cat /var/lib/ug/pc.pkgl);do
		echo -n "${pkg} "
		ln=$(echo "$pkg" | tr '/' '_')
		emerge -u1 "$pkg" &>> "/var/log/ug/rr.${ln}.log" && echo -n "+ " ||\
		emerge -1 "$pkg" &>> "/var/log/ug/rr.${ln}.log" || echo -n "- " && echo -n "+ "
	done
	echo
	reld
	source /etc/profile

##########
#Python updater
##########
#update our python
echo -e "Running python updater:"
	python-updater -p > /var/log/ug/pu.pkgl.dirty
	cat /var/log/ug/pu.pkgl.dirty | grep keep-going | tr ' ' '\n' | awk -F : '{print($1)}' | sort | uniq | egrep -v 'Dv1$|keep-going$|\*$|^emerge$|^$|^-p$' > /var/log/ug/pu.pkgl
	rm /var/log/ug/pu.pkgl.dirty
	echo -e "Emerging python updater list"
	for pkg in $(cat /var/log/ug/pu.pkgl);do 
		ln=$(echo "$pkg" | tr '/' '_')
		echo -e "Emerging ${pkg} for python updater"
		emerge -1 "$pkg" &>> "/var/log/ug/pu.${ln}.log"
		reld
		source /etc/profile
	done

##########
#la file fixer
#Deprecated
##########
#This might not be needed anymore, but whatever.
#echo -e "\n\n\tRunning lafilefixer:\n"
#	lafilefixer --justfixit >> /var/log/ug/la.log 2>> /var/log/ug/la.err.log
#	reld
#	source /etc/profile


#rebuild packages using upgraded libs
echo -e "Emerging preserved-rebuild"
emerge @preserved-rebuild -p --nospin --color n --columns | grep -v ^$ | grep '^\[' | cut -c  18- | awk '{print($1)}' > /var/lib/ug/preserved-rebuild_pkg_list
for pkg in $(cat /var/lib/ug/preserved-rebuild_pkg_list);do
	if [ ! -s /var/lib/ug/preserved-rebuild_pkg_list ]; then
		echo "No preserved-rebuild packages"
		break
	fi
	echo -e -n " ${pkg} "
	#for the log files
	ln=$(echo "$pkg" | tr '/' '_')
	emerge --deep --newuse -1 "$pkg" &>> "/var/log/ug/${ln}.log"
	ret=$?
	if [ "$ret" -lt 1 ];then
		echo "+"
	else
		echo -n "."
		#If that didnt work, try without --deep --newuse, and if something changes underneath we (probably) will catch it on the revdep-rebuild run
		emerge -1 "$pkg" &>> "/var/log/ug/${ln}.log" && echo -n "/" || echo -n "-"
	fi
	reld
	source /etc/profile
done
	


reld
source /etc/profile

echo 'Closing Security check:'
glsa-check -l -q -n affected

rm -fv /var/lib/ug/tmp /var/tmp/portage/* &>> /dev/null

echo 'Services may need to be restarted:'
lsof -n 2>> /dev/null | grep delete | tr ' ' '\n' | grep ^/ | sort -u | egrep -v '^/tmp/|^/tmp/.private/|^/proc/|^/dev/|^/run/'

if [ -x /usr/local/bin/sync_back.sh ]; then
	/usr/local/bin/sync_back.sh
fi
rm -rf /var/tmp/portage/*

