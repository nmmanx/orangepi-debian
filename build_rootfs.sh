#!/bin/bash

SKIP_DEBOOTSTRAP_DEFAULT=1

_ischroot="$(ischroot; test "$?" -eq "1"; echo $?)"
IS_2ND_STATE="$_ischroot"

MOUNTPOINT=/orangepi-debian

OUTDIR=${MOUNTPOINT}/out
ROOTFS=${OUTDIR}/rootfs

mkdir -p $OUTDIR $ROOTFS

if [ "$IS_2ND_STATE" == "0" ]; then
    echo "########## 1st Stage ##########"

    SKIP_DEBOOTSTRAP=$SKIP_DEBOOTSTRAP_DEFAULT

    if [ ! -d $MOUNTPOINT ]; then
        echo "Please run this script inside a container with this dir mounted to $MOUNTPOINT"
        exit 1
    fi
    
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

    echo "Finished 1st stage"

    # Start 2nd state
    sudo cp -v ./build_rootfs.sh ${ROOTFS}/run/
    sudo chroot $ROOTFS bash -c "export SKIP_DEBOOTSTRAP=$SKIP_DEBOOTSTRAP && /run/build_rootfs.sh"

    echo "Done!"
    exit 0
fi

# The below script will run on the new rootfs as root user
echo "########## 2nd Stage ##########"

USERNAME=orangepi
PASSWORD=root
HOSTNAME=orangepi4lts

export LANG=C

if [ "$SKIP_DEBOOTSTRAP" != "1" ]; then
    echo "debootstrap 2nd stage... (could be long, please wait)"
    /debootstrap/debootstrap --keep-debootstrap-dir --verbose --second-stage
else
    echo "Skip debootstrap 2nd stage"
fi

# Require --cap-add=CAP_SYS_ADMIN passed to docker run
mount -t proc none /proc
mount -t sysfs sysfs /sys

apt update
apt install -y sudo

# Init admin user
echo "Adding user"
useradd -m -s /bin/bash -G sudo -u 1000 -p $PASSWORD $USERNAME

# Hostname
echo $HOSTNAME > /etc/hostname
echo "Hostname: $(cat /etc/hostname)"

# Install additional packages
echo "Installing additional packages..."
apt install -y vim net-tools ethtool udev wireless-tools wpasupplicant

echo "Finished 2nd stage"
