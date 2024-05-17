#!/bin/bash

source configs/common

TARGET=$1

if [ ! -d "./configs/$TARGET" ]; then
    echo "Invalid target: $TARGET"
    exit 1
fi

source configs/${TARGET}/config

log "Preparing kernel source code..."
mkdir -p $DOWNLOAD_DIR $KERNEL_SRC $KERNEL_OUT

require_config CONFIG_KERNEL_VERSION
require_config CONFIG_KERNEL_TARBALL_LINK

_tarball_path=${DOWNLOAD_DIR}/$(basename $CONFIG_KERNEL_TARBALL_LINK)

if [ ! -f "$_tarball_path" ]; then
    log "Downloading..."
    wget $CONFIG_KERNEL_TARBALL_LINK -O $_tarball_path
fi
log "Downloaded: $_tarball_path"

if [ ! -f "${KERNEL_SRC}/COPYING" ]; then
    log "Extracting..."
    tar -xf $_tarball_path --strip-components=1 -C $KERNEL_SRC
fi
log "Extracted: $KERNEL_SRC"

require_config CONFIG_KERNEL_DEFCONFIG

source toolchain.sh
if [ "$?" == "0" ]; then
    echo "Toolchain OK"
else
    echo "Missing toolchain!"
    exit 1
fi

KERNEL_MAKE_ARGS="ARCH=arm64 -j4 CROSS_COMPILE=$CROSS_COMPILE_PREFIX -C $KERNEL_SRC O=$KERNEL_OUT"

log "Building kernel..."

if [ -f "$CONFIG_KERNEL_DEFCONFIG" ]; then
    make $KERNEL_MAKE_ARGS defconfig
    cp $CONFIG_KERNEL_DEFCONFIG $KERNEL_OUT/.config
    make $KERNEL_MAKE_ARGS olddefconfig
else
    echo "Missing defconfig: $CONFIG_KERNEL_DEFCONFIG"
    exit 1
fi

make $KERNEL_MAKE_ARGS
test ! "$_?" -eq "0" && exit 1

log "Making deb package..."
rm -v $OUTDIR/linux*
make $KERNEL_MAKE_ARGS "bindeb-pkg"
test ! "$?" -eq "0" && exit 1

echo "Done"
exit 0
