#!/bin/bash

source configs/common

TARGET=$1

if [ ! -d "./configs/$TARGET" ]; then
    echo "Invalid target: $TARGET"
    exit 1
fi

UBOOT_SRC=./deps/u-boot
UBOOT_OUT=$OUTDIR/uboot

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

UBOOT_MAKE_CMD="make ARCH=arm -j4 CROSS_COMPILE=$CROSS_COMPILE_PREFIX -C $UBOOT_SRC O=$UBOOT_OUT $CONFIG_UBOOT_EXTRA_MAKE_ARGS "

mkdir -p $UBOOT_OUT

echo "TARGET=$TARGET"
echo "CONFIG_UBOOT_DEFCONFIG=$CONFIG_UBOOT_DEFCONFIG"
echo "UBOOT_MAKE_CMD=\"$UBOOT_MAKE_CMD\""

if [ -f "$CONFIG_UBOOT_DEFCONFIG" ]; then
    eval $UBOOT_MAKE_CMD defconfig
    cp $CONFIG_UBOOT_DEFCONFIG $UBOOT_OUT/.config
    eval $UBOOT_MAKE_CMD olddefconfig
else
    eval $UBOOT_MAKE_CMD $CONFIG_UBOOT_DEFCONFIG
fi

_logargs="> ${UBOOT_OUT}/uboot_build.log 2<&1"
eval $UBOOT_MAKE_CMD $_logargs

if [ "$?" == "0" ]; then
    echo "Built U-Boot: $UBOOT_OUT"
else
    echo "Build U-Boot failed, check: $(UBOOT_OUT)/uboot_build.log"
    exit 1
fi
