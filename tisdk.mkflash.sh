#!/bin/bash 
# -------------------------------------------------------------------------
# mkflash - Build a bootable SD card from the build result.
#
# prepAndPartition()
# formatPartitions()
# copyRootfsKernel()
# unMountDevice()
#
# Syntax: mkflash <device-file> <mountpoint> e.g. mkflash /dev/sdb /flash
# -------------------------------------------------------------------------


die()
{
    printf "$@"
    exit 1
}

readYN()
{
        if [ -n "$PROMPT" ] ; then
            read yn
            case $yn in
                y|Y) return 0 ;;
                *)   return 1 ;;
            esac
        else
                return 0 ;
        fi
        return 1 ;
}

# --------------------------------------------
# check parameters
#
function usage () {
    local msg="$*";
    [ -n "$msg" ] && msg="\nError: $msg\n";
    die "$msg\n\
Syntax: $0 --tgt=TargetDir --dev=DEVICE [--mount=MOUNTPOINT] [--boot=BOOT] [--rootfs=ROOTFS] [--part=PARTITION_LAYOUT_FILE] [--prompt] \n\
    e.g. $0 --dev=/dev/sdc --mount=/mnt/flash --boot=boot.tar.gz -rootfs=rootfs.tar.gz --part=sfpart.file.txt\n\
    MOUNTPOINT defaults to ./flash \n\
    BOOT default $BOOT \n\
    ROOTFS default $ROOTFS \n\
    PARTITION_LAYOUT_FILE is an sfdisk compatible file (made with sfdisk -d) and defaults to partition_layout.sfdisk\n\
    PROMPT prompting for y/n default=y \n\
    ";
}

# --------------------------------------------
# Un Mount the target device
function unMountDevice () {
	echo "umount"
	touch $MOUNTPOINT/root/forcefsck
	ls -al $MOUNTPOINT/boot

	umount $MOUNTPOINT/boot
	umount $MOUNTPOINT/root
}

# --------------------------------------------
#  prepPartition device
function prepAndPartition() {
	echo "check mount point"

	# check the mount point
	#
	if ! [ -d "$MOUNTPOINT" ]; then
        [ -n $PROMPT ] && printf "NOTE: Mountpoint '$MOUNTPOINT' does not exist, create it?\n" ;
        readYN  || die "Please create or specify an existing directory for the mountpoint";
        mkdir -p $MOUNTPOINT || die "Failed to create mountpoint '$MOUNTPOINT'";
    fi


    # Partition the sd card
    #
    [ -n "$PROMPT" ] && printf "\nDo you want to partition $DEV (y/n)? "
    if readYN ; then

    	#
    	# sfdisk has problems if the partition table isn't destroyed first. Sometimes
    	# it has trouble even then.
    	#
    	dd if=/dev/zero of=$DEV bs=1024 count=2
    	sync
    	sleep 1

    	sfdisk -f $DEV < $PART || die "Failed to partition '$DEV'";

    	sleep 1
    fi
}



# --------------------------------------------
####
# Expecting something like the following
#   Device Boot    Start       End   #sectors  Id  System
#/dev/sdb1          2048    206847     204800   b  W95 FAT32
#/dev/sdb2        206848   5941247    5734400  83  Linux
#/dev/sdb3       5941248  11675647    5734400  83  Linux
#/dev/sdb4      11675648  31115263   19439616   5  Extended
#/dev/sdb5      11677696  23146495   11468800  83  Linux
#/dev/sdb6      23148544  31115263    7966720  83  Linux

# 1=boot
# 2=rootfs   2,3 will swap back and forth on successive updates.
# 3=rootfs
# 4=extend
#   5= data,dbase,logs
#   6= updates,config

# --------------------------------------------
# Format the partitions
#
function formatPartitions () {
	sleep 1
	[ -n "$PROMPT" ] && printf "\nDo you want to format the partitions (y/n)? "

	if readYN ; then
		# done above before sfdisk called. dd if=/dev/zero of=${DEV}1 bs=512 count=1 ; sync ; sleep 1;
		printf "\n formatting... \n "
		mkfs.vfat -F 32  ${DEV}1 -n "boot" || die "\nError running mkfs on ${DEV}1\n"
		mkfs.ext3 -L "rootfs" ${DEV}2  || die "\nError running mkfs on ${DEV}2\n"
	fi
}

# --------------------------------------------
# Mount Copy Rootfs Kernel
#
function copyRootfsKernel () {
	# --------------------------------------------
	# Copy the rootfs and kernel
	#
	sleep 1

	[ -d "$MOUNTPOINT/boot" ] || mkdir $MOUNTPOINT/boot
	[ -d "$MOUNTPOINT/root" ] || mkdir "$MOUNTPOINT/root"

	mount -t vfat ${DEV}1 $MOUNTPOINT/boot
	mount ${DEV}2 $MOUNTPOINT/root

	echo "start copy uboot...$TGT"
	
	srcdir="$TGT"
	[ ! -d "$srcdir" ] && die "The target dir ($srcdir) was not found"
	
	#pushd $srcdir
	#  [ ! -e "./zImage" ] && popd && echo "missing ./$srcdir/zImage " && unMountDevice && exit 1
	#  cat zImage zImage-am335x-evm.dtb > myzimage
	#  #mkimage -A arm -O linux -T kernel -C none -a 0x80008000 -e 0x80008000 -n "ARM Linux kernel 3.14.41" -d ./zImage uImage
	#  mkimage -A arm -O linux -T kernel -C none -a 0x80008000 -e 0x80008000 -n "ARM Linux kernel 3.14.41" -d ./myzimage myuimage
	#popd

	# MLO
	[ -f "$srcdir/MLO" ] && cp $srcdir/{MLO,u-boot.img,u-boot-spl.bin} $MOUNTPOINT/boot
	# uImage
	if [ -f "$srcdir/uImage" ] ; then
		[ $TGT == "tisdk" ] && cat $srcdir/uImage $srcdir/uImage-am335x-evm.dtb > $srcdir/myuimage
		[ $TGT == "beagle" ] && cat $srcdir/uImage $srcdir/zImage-am335x-bone.dtb > $srcdir/myuimage
		cp $srcdir/myuimage $MOUNTPOINT/boot/uImage
		cp $srcdir/myuimage $MOUNTPOINT/root/boot/uImage
	fi
	
	cp .ipaddr $MOUNTPOINT/boot
	cp uEnv.txt $MOUNTPOINT/boot

	# untar File system
	echo "start copy rootfs..."
	[ $TGT == "tisdk" ] && tar -C $MOUNTPOINT/root -xzvf $srcdir/core-image-minimal-am335x-evm.tar.gz && tar -C $MOUNTPOINT/root -xzvf $srcdir/modules-am335x-evm.tgz
	[ $TGT == "beagle" ] && tar -C $MOUNTPOINT/root -xzvf $srcdir/core-image-minimal-beaglebone.tar.gz && tar -C $MOUNTPOINT/root -xzvf $srcdir/modules-beaglebone.tgz

	# uImage to rootfs
	# DTB to rootfs
#	[ $TGT == "tisdk" ]  && cp $srcdir/uImage-a*.dtb $MOUNTPOINT/boot/
#	[ $TGT == "beagle" ] && cp $srcdir/zImage-a*.dtb $MOUNTPOINT/root/boot
	
	
	cp am33x-cm3/bin/am335x-pm-firmware.* $MOUNTPOINT/root/lib/firmware
	cp tisdk/tmp/lib/firmware/am33* $MOUNTPOINT/root/lib/firmware

	sync ; printf " Done..tar rootfs to partition." ; sleep 1
}

################################################################################
#   MAIN 
###############################################################################

# ---- Get the inputs ----

DEV="/dev/"`tail -n 50 /var/log/syslog | grep "sd.:" | awk '{ print  $7 }' | cut -d":" -f1 |tail -n 1`
if [ -z "$DEV" ] ; then 
	DEV=`cat ./device.txt`
fi

MOUNTPOINT='./flash'
PART='part.sfdisk'
BOOT='./rpi-2012-10-28-boot.tgz'
ROOTFS='./rpi-2012-10-28-rootfs.tgz'

PROMPT='y'

TGT="tisdk"

# ----------------------------------------------------------------------
# make sure this is run by root
#
[ $(id -u) -eq 0 ] || die "\nThis must be run by root\n"

while [ -n "$1" ]; do
    [ "x${1:0:2}" = "x--" ] || die "Invalid argument '$1'";

    name="${1:2}";
    val=;
    [ -n "${name//[^=]/}" ] && val="${name##*=}"
    name="${name//=*}"

    case "$name" in
        dev)      DEV="$val" ;;
        mount)    MOUNTPOINT="$val" ;;
        part)     PART="$val" ;;
        boot)     BOOT="$val" ;;
        rootfs)   ROOTFS="$val" ;;
        prompt)   PROMPT="$val" ;;
        tgt)      TGT="$val" ;;
        *)       die "Invalid argument '$name'" ;;
    esac;
    shift;
done;

[ -n "$MOUNTPOINT" ] || usage "you must specify a mountpoint"
[ -b "$DEV"     ] || usage "Device '$dev' does not exist or is not a block device";
[ -r "$PART"    ] || usage "Partition layout file '$PART' does not exist or is not readable";
[ -n "$TGT"  ] || usage "You must specify target dir tisdk,beaglebone.poky,banalore";

echo "--dev=$DEV ,--mount=$MOUNTPOINT, --boot=$BOOT , --rootfs=$ROOTFS , --part=$PART "

# ----------------------------------------------------------------------
# make sure the device is a base file, not a partition
#
if [[ $DEV =~ /dev/sd[a-z][0-9] ]]; then
    die "\n$DEV is not the base device file\n\n"
fi

# ----------------------------------------------------------------------
# make sure the device file is not mounted
#
mountedPartitions=$("mount")
if [[ $mountedPartitions =~ $DEV ]]; then
    die "\none or more partitions on $DEV is mounted\n\n"
fi

# --------------------------------------------
# confirmations : set Prompt.
#
if [[ "$PROMPT" != [Yy]* ]] ; then
        #echo set PROMPT null
        PROMPT=""
else
        printf "\n WARNING! \n"
        printf "\nAre you SURE [$DEV] is the right partition (y/n or ^C)? "
fi

readYN || exit 0

prepAndPartition

formatPartitions

copyRootfsKernel

unMountDevice 

echo " fsck partitions..."
fsck.vfat -y ${DEV}1
fsck -y ${DEV}2

echo "..Completed..You can remove SD card.";
