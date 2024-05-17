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
require_config CONFIG_SD_BOOT_END_LBA
require_config CONFIG_LOADER_OFFSET

_padding_lba=8
_rootfs_size=$(sudo du -s --apparent-size --exclude=/{proc,sys,dev,boot} --block-size=$CONFIG_SD_BLOCK_SIZE $ROOTFS | cut -f 1)
_estimated_img_size=$((${CONFIG_SD_ROOTFS_START_LBA} + ${_rootfs_size} + ${_padding_lba}))

echo "Rootfs size: $_rootfs_size (LBA)" 
echo "Estimated image size: $_estimated_img_size (LBA)" 

rm -f $IMG_PATH
dd if=/dev/zero of=$IMG_PATH bs=$CONFIG_SD_BLOCK_SIZE count=$_estimated_img_size conv=notrunc

_loopdev_mirror=${HOST_MIRROR}$(sudo losetup -f)
echo "Loop device: $_loopdev_mirror"

update_rootfs_uuid () {
    local _uuid=$1
    local _extlinux=$2
    sudo sed -i -E "s/root=UUID=.{36}/root=UUID=$_uuid/g" $_extlinux
    echo "Updated rootfs partition UUID in \"$_extlinux\":"
    cat $_extlinux | grep root=
}

# Ensure loopback device
if [[ "$_loopdev_mirror" == ${HOST_MIRROR}/dev/loop* ]]; then
    sudo losetup $_loopdev_mirror $IMG_PATH
    sudo losetup -l

    # 1) create GPT partition table
    log "Create GPT partition table"
    sudo parted -s $_loopdev_mirror mklabel gpt
    sudo parted -s $_loopdev_mirror unit s

    # 2) create boot partition
    log "Create boot partition"
    sudo parted -s $_loopdev_mirror mkpart primary fat16 ${CONFIG_SD_BOOT_START_LBA}s ${CONFIG_SD_BOOT_END_LBA}s
    sudo parted -s $_loopdev_mirror name 1 'boot' 
    sudo parted -s $_loopdev_mirror set 1 boot on

    # 3) create rootfs partition
    log "Create rootfs partition"
    sudo parted -s $_loopdev_mirror mkpart primary ext4 ${CONFIG_SD_ROOTFS_START_LBA}s 100%
    sudo parted -s $_loopdev_mirror name 2 'rootfs'

    # 4) create file systems
    log "Create file systems"
    sudo partprobe -s ${_loopdev_mirror}
    sudo mkfs.vfat -F 16 ${_loopdev_mirror}p1
    sudo mkfs.ext4 ${_loopdev_mirror}p2

    # 5) copy data
    log "Copying data..."
    sudo mkdir -p /mnt/sd/boot /mnt/sd/rootfs

    sudo mount ${_loopdev_mirror}p1 /mnt/sd/boot
    sudo mkdir -p /mnt/sd/boot/boot

    sudo sudo sudo rsync -ac --block-size=$CONFIG_SD_BLOCK_SIZE $ROOTFS/boot/ /mnt/sd/boot/boot
    sudo ls -l /mnt/sd/boot/boot

    sudo mount ${_loopdev_mirror}p2 /mnt/sd/rootfs
    sudo sudo rsync -ac --block-size=$CONFIG_SD_BLOCK_SIZE \
        --exclude "boot" \
        --exclude "proc" \
        --exclude "sys" \
        --exclude "dev" \
        --exclude "tmp" \
        --exclude "mnt" \
        --exclude "debootstrap" \
        --exclude "lost+found" \
        $ROOTFS/ \
        /mnt/sd/rootfs
    
    sudo mkdir -p \
        /mnt/sd/rootfs/boot \
        /mnt/sd/rootfs/proc \
        /mnt/sd/rootfs/sys \
        /mnt/sd/rootfs/dev \
        /mnt/sd/rootfs/tmp \
        /mnt/sd/rootfs/mnt 

    sudo ls -l /mnt/sd/rootfs
    
    _rootfs_part_uuid=$(sudo blkid ${_loopdev_mirror}p2 | grep -oP '(?<=UUID=")[^\"]+')
    echo "Rootfs partition UUID: $_rootfs_part_uuid"
    update_rootfs_uuid $_rootfs_part_uuid /mnt/sd/boot/boot/extlinux/extlinux.conf
    
    sudo umount /mnt/sd/boot
    sudo umount /mnt/sd/rootfs

    # 6) burn bootloaders
    log "Burn bootloaders..."
    sudo dd if=$LOADER_OUT/loaders.img of=$_loopdev_mirror seek=$CONFIG_LOADER_OFFSET conv=fsync

    # 7) double check
    sudo fsck.vfat ${_loopdev_mirror}p1 || echo "WARNING: check boot partition failed"
    sudo fsck.ext4 ${_loopdev_mirror}p2 || echo "WARNING: check rootfs partition failed"

    # 8) finished
    sudo parted -s $_loopdev_mirror unit MiB print
    sudo losetup -d $_loopdev_mirror

    # TODO: read rootfs UUID and pass to kernel cmdline in extlinux.conf
else
    log "Error: invalid loop device: $_loopdev_mirror"
    exit 1
fi

mv $IMG_PATH ${OUTDIR}/${TARGET}_sd.raw
log "Output: ${OUTDIR}/${TARGET}_sd.raw"
exit 0
