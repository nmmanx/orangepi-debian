#!/bin/bash

SKIP_DEBOOTSTRAP=0
SHELL_MODE=0

CHROOT_LOG_FILE=/tmp/main.log

_ischroot="$(ischroot; test "$?" -eq "1"; echo $?)"
IS_2ND_STATE="$_ischroot"

TARGET=${@: -1}
if [ -z "$TARGET" ]; then
    echo "Missing target"
    show_help
    exit 1
fi

echo "TARGET=$TARGET"

if [ "$IS_2ND_STATE" == "0" ]; then
source configs/common
source configs/${TARGET}/config
ROOTFS=${OUTDIR}/rootfs
else
source /tmp/common
source /tmp/config
MAIN_LOG_FILE=$CHROOT_LOG_FILE
ROOTFS=
fi

show_help () {
    cat <<EOF
Usage: build_rootfs.sh [OPTIONS] [TARGET]
OPTIONS:
    -k, --skip-debootstrap      Skip executing debootstrap again
    -s, --shell                 Run a shell within the created rootfs
    -h, --help                  Show this help
EOF
}

ARGS=$@
OPTS=${@: 1: $(($# - 1))}
echo "OPTS=$OPTS"

GETOPT_ARGS=$(getopt -o k,s,h --long skip-debootstrap,shell,help -- "$OPTS")
if [ "$?" != "0" ]; then
    echo "Invalid arguments"
    show_help
    exit 1;
fi

eval set -- "$GETOPT_ARGS"

while [ : ]; do
  case "$1" in
    -k | --skip-debootstrap)
        SKIP_DEBOOTSTRAP=1
        shift
        ;;
    -s | --shell)
        SHELL_MODE=1
        shift
        ;;
    -h | --help)
        show_help
        exit 0
        ;;
    --) shift; 
        break 
        ;;
  esac
done

if [ "$SHELL_MODE" == "1" ]; then
    echo "root" | sudo -S  echo "Auto gain root permission"
    sudo mount -t proc none $ROOTFS/proc
    sudo mount -t sysfs sysfs $ROOTFS/sys
    sudo chroot $ROOTFS /bin/bash -i
    exit 0
fi

if [ "$IS_2ND_STATE" == "0" ]; then
    log "########## 1st Stage ##########"
    ROOTFS=${OUTDIR}/rootfs

    mkdir -p $OUTDIR $ROOTFS

    if [ ! -d $MOUNTPOINT ]; then
        echo "Please run this script inside a container with this dir mounted to $MOUNTPOINT"
        exit 1
    fi
    
    echo "root" | sudo -S  echo "Auto gain root permission"

    if [ "$SKIP_DEBOOTSTRAP" != "1" ]; then
        log "debootstrap 1st stage..."
        sudo debootstrap --arch=arm64 --foreign --variant=minbase --verbose buster $ROOTFS
    else
        log "Skip debootstrap 1st stage"
    fi

    sudo cp -v /usr/bin/qemu-aarch64-static ${ROOTFS}/usr/bin/
    echo "nameserver 8.8.8.8" | sudo tee ${ROOTFS}/etc/resolv.conf
    echo "nameserver 8.8.4.4" | sudo tee -a ${ROOTFS}/etc/resolv.conf

    # Copy kernel deb packages
    sudo mkdir -p ${ROOTFS}/tmp/kernel
    sudo rm ${ROOTFS}/tmp/kernel/*
    sudo find ${OUTDIR} -maxdepth 1 -type f -name linux\-* -exec cp -v {} ${ROOTFS}/tmp/kernel/ \;

    # Copy u-boot-menu config
    require_config CONFIG_UBOOT_MENU_CONF
    sudo mkdir -p ${ROOTFS}/tmp/uboot
    sudo cp -v $CONFIG_UBOOT_MENU_CONF ${ROOTFS}/tmp/uboot/u-boot-menu.conf

    log "Finished 1st stage"

    # Start 2nd state
    sudo cp -v ./build_rootfs.sh ${ROOTFS}/run/
    sudo cp -v configs/common ${ROOTFS}/tmp/common
    sudo cp -v configs/$TARGET/config ${ROOTFS}/tmp/config

    # Redirect chroot log file to main log file
    echo "" | sudo tee ${ROOTFS}/${CHROOT_LOG_FILE}
    sudo tail -n0 -f --pid=$PID ${ROOTFS}${CHROOT_LOG_FILE} >> $MAIN_LOG_FILE &

    sudo chroot $ROOTFS bash -c "/run/build_rootfs.sh $ARGS"

    echo "Done!"
    exit 0
fi

# The below script will run on the new rootfs as root user
log "########## 2nd Stage ##########"

export LANG=C

require_config CONFIG_USERNAME
require_config CONFIG_PASSWORD
require_config CONFIG_HOSTNAME
require_config CONFIG_PACKAGES

if [ "$SKIP_DEBOOTSTRAP" != "1" ]; then
    log "debootstrap 2nd stage... (could be long, please wait)"
    /debootstrap/debootstrap --keep-debootstrap-dir --verbose --second-stage
else
    log "Skip debootstrap 2nd stage"
fi

# Require --cap-add=CAP_SYS_ADMIN passed to docker run
mount -t proc none /proc
mount -t sysfs sysfs /sys

apt update
apt install -y sudo

# Init admin user
log "Adding user"
useradd -m -s /bin/bash -G sudo -u 1000 -p $CONFIG_PASSWORD $CONFIG_USERNAME
echo ${CONFIG_USERNAME}:${CONFIG_PASSWORD} | chpasswd

# Hostname
echo $CONFIG_HOSTNAME > /etc/hostname
echo "Hostname: $(cat /etc/hostname)"

# Install required packages
log "Installing required packages..."
apt install -y u-boot-menu initramfs-tools

if [ -n "$(ls /tmp/kernel/*.buildinfo)" ]; then
    log "Checking kernel package..."
    _kbuildinfo=$(find /tmp/kernel/ -iname *.buildinfo)
    
    _kprefix=$(cat $_kbuildinfo | awk '/^Binary:/{ print $2 }')
    _kversion=$(cat $_kbuildinfo | awk '/^Version:/{ print $2 }')
    _karch=$(cat $_kbuildinfo | awk '/^Architecture:/{ print $2 }')
    _kdeb=/tmp/kernel/${_kprefix}_${_kversion}_${_karch}.deb

    if [ -f "$_kdeb" ]; then
        log "Install kernel package: $_kdeb"
        apt install -y $_kdeb
    fi

    update-initramfs -c -v -k "$(echo $_kprefix | cut -d "-" -f 3)"
else
    echo "Kernel buildinfo file not found"
    exit 1
fi

export DEBIAN_FRONTEND="noninteractive"

log "Installing additional packages..."
apt install -y $CONFIG_PACKAGES
apt install --fix-broken

# Prepare extlinux.conf
log "Update uboot boot entry"
cp /tmp/uboot/u-boot-menu.conf /etc/default/u-boot
u-boot-update
echo "Dump extlinux.conf:"
cat /boot/extlinux/extlinux.conf

log "Cleaning up..."
apt -y autoremove

umount /proc
umount /sys

log "Finished 2nd stage"
exit 0
