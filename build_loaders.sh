#!/bin/bash

source configs/common

TARGET=$1

if [ ! -d "./configs/$TARGET" ]; then
    echo "Invalid target: $TARGET"
    exit 1
fi

source toolchain.sh
if [ "$?" == "0" ]; then
    echo "Toolchain OK"
else
    echo "Missing toolchain!"
    exit 1
fi

source configs/${TARGET}/config
if [ "$?" == "0" ]; then
    echo "Configured OK"
else
    echo "Configuration failed"
    exit 1
fi

UBOOT_MAKE_ARGS="ARCH=arm -j4 CROSS_COMPILE=$CROSS_COMPILE_PREFIX -C $UBOOT_DIR O=$UBOOT_OUT $CONFIG_UBOOT_EXTRA_MAKE_ARGS"

mkdir -p $UBOOT_OUT

require_config CONFIG_UBOOT_DEFCONFIG
require_config CONFIG_LOADER_MAKE_SCRIPT

echo "TARGET=$TARGET"
echo "CONFIG_UBOOT_DEFCONFIG=$CONFIG_UBOOT_DEFCONFIG"
echo "UBOOT_MAKE_ARGS=\"$UBOOT_MAKE_ARGS\""

log "Building U-Boot..."

if [ -f "$CONFIG_UBOOT_DEFCONFIG" ]; then
    make $UBOOT_MAKE_ARGS defconfig
    cp $CONFIG_UBOOT_DEFCONFIG $UBOOT_OUT/.config
    make $UBOOT_MAKE_ARGS olddefconfig
else
    echo "Missing defconfig: $CONFIG_UBOOT_DEFCONFIG"
    exit 1
fi

make $UBOOT_MAKE_ARGS
test ! "$?" -eq "0" && exit 1

log "Making loaders..."
source $CONFIG_LOADER_MAKE_SCRIPT $TARGET
