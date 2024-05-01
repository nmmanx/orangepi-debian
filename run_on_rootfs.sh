#!/bin/bash

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

echo "Done setup rootfs"
