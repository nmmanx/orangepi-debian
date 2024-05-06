#!/bin/bash

source configs/common

TARGET=$1

if [ ! -d "./configs/$TARGET" ]; then
    echo "Invalid target: $TARGET"
    exit 1
fi

source configs/${TARGET}/config

echo "Preparing kernel source code..."
mkdir -p $DOWNLOAD_DIR $KERNEL_SRC $KERNEL_OUT

require_config CONFIG_KERNEL_VERSION
require_config CONFIG_KERNEL_TARBALL_LINK

_tarball_path=${DOWNLOAD_DIR}/$(basename $CONFIG_KERNEL_TARBALL_LINK)

if [ ! -f "$_tarball_path" ]; then
    echo "Downloading..."
    wget $CONFIG_KERNEL_TARBALL_LINK -O $_tarball_path
fi
echo "Downloaded: $_tarball_path"

if [ ! -f "${KERNEL_SRC}/COPYING" ]; then
    echo "Extracting..."
    tar -xf $_tarball_path --strip-components=1 -C $KERNEL_SRC
fi

require_config CONFIG_KERNEL_DEFCONFIG

source toolchain.sh
if [ "$?" == "0" ]; then
    echo "Toolchain OK"
else
    echo "Missing toolchain!"
    exit 1
fi

KERNEL_MAKE_CMD="make ARCH=arm64 -j4 CROSS_COMPILE=$CROSS_COMPILE_PREFIX -C $KERNEL_SRC O=$KERNEL_OUT "

if [ -f "$CONFIG_KERNEL_DEFCONFIG" ]; then
    eval $KERNEL_MAKE_CMD defconfig
    cp $CONFIG_KERNEL_DEFCONFIG $KERNEL_OUT/.config
    eval $KERNEL_MAKE_CMD olddefconfig
else
    eval $KERNEL_MAKE_CMD $CONFIG_KERNEL_DEFCONFIG
fi

_logargs=" 2>&1 | tee ${KERNEL_OUT}/kernel_build.log"
eval $KERNEL_MAKE_CMD $_logargs

if [ "$?" == "0" ]; then
    echo "Built kernel: $KERNEL_OUT"
else
    echo "Build kernel failed, check: $KERNEL_OUT/kernel_build.log"
    exit 1
fi

echo "Done"
