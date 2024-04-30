#!/bin/bash

MOUNTPOINT=/orangepi-debian

if [ ! -d $MOUNTPOINT ]; then
    echo "Please run this script inside a container with this dir mounted to $MOUNTPOINT"
    exit 1
fi

OUTDIR=${MOUNTPOINT}/out
ROOTFS=${OUTDIR}/rootfs

mkdir -p $OUTDIR $ROOTFS 

sudo debootstrap --arch=arm64 --foreign --variant=minbase buster $ROOTFS

sudo cp -v /usr/bin/qemu-aarch64-static ${ROOTFS}/usr/bin/
echo "nameserver 8.8.8.8" | sudo tee ${ROOTFS}/etc/resolv.conf

sudo cp -v ./run_on_rootfs.sh ${ROOTFS}/run/
sudo chroot $ROOTFS "/run/run_on_rootfs.sh"

echo "Done"
