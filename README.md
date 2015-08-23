
## sdcard-tisdk
Create Uboot sdcard from arago builds.

Tools:  
- Linux ubuntu 14.04 lts
- USB card reader

Add firmware dir for am33x ti arm cortex8 .   
am33x-cm3 Firmware.   
```
   git clone git://arago-project.org/git/projects/am33x-cm3.git
```

- Below I use a micro Sdcard partition, format, copy boot files [uboot, uImage, dtb files].  

Main file is <name>.mkflash.sh  
i.e. :  
  bone.mkflash.sh
The mkflash, Conditionaly partitions and formats a sdcard with two partitions mmcblk0p1 /boot and mmcblk0p2 /root.  


- Create symbolic link to Deploy directories of Arago ./build directory
i.e. :  
```
      tisdk -> ~/dev/dcim3.x/tisdk/build/arago-tmp-external-linaro-toolchain/deploy/images/am335x-evm
```

This is referenced from the bone.mkflash.sh to create an SD-card

