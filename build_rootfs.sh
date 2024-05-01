#!/bin/bash

MOUNTPOINT=/orangepi-debian
SKIP_DEBOOTSTRAP=0

if [ ! -d $MOUNTPOINT ]; then
    echo "Please run this script inside a container with this dir mounted to $MOUNTPOINT"
    exit 1
fi

OUTDIR=${MOUNTPOINT}/out
ROOTFS=${OUTDIR}/rootfs

mkdir -p $OUTDIR $ROOTFS

echo "root" | sudo -S  echo "Auto gain root permission"

if [ "$SKIP_DEBOOTSTRAP" != "1" ]; then
    echo "debootstrap 1st stage..."
    sudo debootstrap --arch=arm64 --foreign --variant=minbase --verbose buster $ROOTFS
else
    echo "Skip debootstrap 1st stage"
fi

sudo cp -v /usr/bin/qemu-aarch64-static ${ROOTFS}/usr/bin/
echo "nameserver 8.8.8.8" | sudo tee ${ROOTFS}/etc/resolv.conf
echo "nameserver 8.8.4.4" | sudo tee -a ${ROOTFS}/etc/resolv.conf

sudo cp -v ./run_on_rootfs.sh ${ROOTFS}/run/
sudo chroot $ROOTFS bash -c "export SKIP_DEBOOTSTRAP=$SKIP_DEBOOTSTRAP && /run/run_on_rootfs.sh"

echo "Done"
