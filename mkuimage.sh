#!/bin/bash

if [ -z "$1" ] ; then
   mydir="tisdk"
else
   mydir="$1"
fi

pushd $mydir
mkimage -A arm -O linux -T kernel -C none -a 0x80008000 -e 0x80008000 -n "ARM Linux kernel 3.14.41" -d ./zImage uImage
popd 
