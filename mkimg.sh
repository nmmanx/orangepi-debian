#!/bin/bash

source configs/common

TARGET=$1
IMG_PATH=$OUTDIR/debian.img

if [ ! -d "./configs/$TARGET" ]; then
    echo "Invalid target: $TARGET"
    exit 1
fi
source configs/$TARGET/config

require_config CONFIG_SD_BLOCK_SIZE
require_config CONFIG_SD_ROOTFS_START_LBA
require_config CONFIG_SD_BOOT_START_LBA
require_config CONFIG_SD_BOOT_SIZE_MIB
require_config CONFIG_LOADER_OFFSET

_padding_lba=8
_rootfs_size=$(sudo du -s --block-size=$CONFIG_SD_BLOCK_SIZE $ROOTFS | cut -f 1)
_estimated_img_size=$((${CONFIG_SD_ROOTFS_START_LBA} + ${_rootfs_size} + ${_padding_lba}))

echo "Rootfs size: $_rootfs_size (LBA)" 
echo "Estimated image size: $_estimated_img_size (LBA)" 

rm -f $IMG_PATH
dd if=/dev/zero of=$IMG_PATH bs=$CONFIG_SD_BLOCK_SIZE count=$_estimated_img_size conv=notrunc

_loopdev=$FREE_LOOP_DEV
echo "Loop device: $_loopdev"

# Ensure loopback device
if [[ "$_loopdev" == /dev/loop* ]]; then
    sudo losetup $_loopdev $IMG_PATH
    sudo losetup -l

    # 1) create GPT partition table
    echo "Create GPT partition table"
    sudo parted -s $_loopdev mklabel gpt

    # 2) create boot partition
    echo "Create boot partition"
    _start=$(($CONFIG_SD_BOOT_START_LBA * $CONFIG_SD_BLOCK_SIZE / 1048576)) # Mib
    echo "Boot start: $_start Mib"
    sudo parted -s $_loopdev mkpart primary fat32 $_start $CONFIG_SD_BOOT_SIZE_MIB
    sudo parted -s $_loopdev name 1 'boot' 
    sudo parted -s $_loopdev set 1 boot on

    # 3) create rootfs partition
    echo "Create rootfs partition"
     _start=$(($CONFIG_SD_ROOTFS_START_LBA * $CONFIG_SD_BLOCK_SIZE / 1048576)) # Mib
     echo "Rootfs start: $_start Mib"
    sudo parted -s $_loopdev mkpart primary ext4 $_start 100%
    sudo parted -s $_loopdev name 2 'rootfs'

    # 4) create file systems
    sudo partprobe -s ${_loopdev}
    sudo mkfs.vfat ${_loopdev}p1
    sudo mkfs.ext4 ${_loopdev}p2

    # 5) copy data
    # TODO

    # 6) burn bootloaders
    sudo dd if=$LOADER_OUT/loaders.img of=$_loopdev bs=$CONFIG_SD_BLOCK_SIZE seek=$CONFIG_LOADER_OFFSET

    sudo parted -s $_loopdev print
    sudo losetup -d $_loopdev
else
    echo "Error: invalid loop device: $_loopdev"
    exit 1
fi

echo "Done"
