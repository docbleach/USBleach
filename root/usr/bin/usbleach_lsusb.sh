#!/bin/ash
# Taken from usbutils and modified to garantee some things over lsusb:
# - Easy parsing, even in Lua: "I: Dev=(.+) ..." for interfaces and "T:
# - Predictable order: devices are ordered by ascending ID, and the tree is pre-made (natural order)
# - Interfaces are grouped with the device they belong to (one "T" followed by multiple "I")

# Copyright: 2009 Greg Kroah-Hartman <greg@kroah.com>
#            2009 Randy Dunlap <rdunlap@xenotime.net>
#            2009 Frans Pop <elendil@planet.nl>
#
# This software may be used and distributed according to the terms of
# the GNU General Public License (GPL), version 2, or at your option
# any later version.

print_string() {
	file=$1
	name=$2
	[ -f ${file} ] || return
	echo "S:  $name=`cat $file`"
}

print_interface() {
	local ifpath=$1

	ifnum=`cat ${ifpath}/bInterfaceNumber`
	altset=`cat ${ifpath}/bAlternateSetting`
	numeps=`cat ${ifpath}/bNumEndpoints`
	# Not used -^

	class=`cat ${ifpath}/bInterfaceClass`
	subclass=`cat ${ifpath}/bInterfaceSubClass`
	protocol=`cat ${ifpath}/bInterfaceProtocol`

	printf "I:  Dev=%s Cls=%s Sub=%s Prot=%s\n" ${ifpath} ${class} ${subclass} ${protocol}
}

print_device() {
	local devpath=$1
	local parent=$2
	local level=$3
	local count=$4

	[ -d ${devpath} ] || return
	cd ${devpath}

	local busnum=`cat busnum`
	local devnum=`cat devnum`

	if [ ${level} -gt 0 ]; then
		port=$((${devpath##*[-.]} - 1))
	else
		port=0
	fi

	ver=`cat version`
	devclass=`cat bDeviceClass`
	devsubclass=`cat bDeviceSubClass`
	devprotocol=`cat bDeviceProtocol`
	maxps0=`cat bMaxPacketSize0`
	numconfigs=`cat bNumConfigurations`
	vendid=`cat idVendor`
	prodid=`cat idProduct`

	printf "\nT:  Dev=%s Lev=%02i Cls=%s Sub=%s Prot=%s Vendor=%s ProdID=%s\n" \
	    ${devpath} ${level} ${devclass} ${devsubclass} ${devprotocol} ${vendid} ${prodid}

	for interface in ${busnum}-*:?.*
	do
		print_interface ${devpath}/${interface}
	done

	local devcount=0
	for subdev in ${busnum}-*
	do
		echo "$subdev" | grep -Eq "^$busnum-[0-9]+(\.[0-9]+)*$" || continue

		devcount=$(($devcount + 1))
		if [ -d ${devpath}/${subdev} ]; then
			print_device ${devpath}/${subdev} \
				${devnum} $(($level +1)) ${devcount}
		fi
	done
}

if [ ! -d /sys/bus ]; then
	echo "Error: directory /sys/bus does not exist; is sysfs mounted?" >&2
	exit 1
fi

for device in /sys/bus/usb/devices/usb*
do
	print_device ${device} 0 0 0
done
