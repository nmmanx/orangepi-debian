#!/bin/bash

source configs/common

TARGET=$1
if [ ! -d "./configs/$TARGET" ]; then
    echo "Invalid target: $TARGET"
    exit 1
fi
source configs/$TARGET/config

mkdir -p $LOADER_OUT

echo "Making idbloader.img..."
cd $RKBIN_DIR && tools/mkimage -n $CONFIG_ROCKCHIP_PLATFORM \
    -T rksd -d $CONFIG_ROCKCHIP_DDR_BIN $LOADER_OUT/idbloader.img

echo "Making uboot_rk.img..."
cd $RKBIN_DIR && tools/loaderimage --pack --uboot $UBOOT_OUT/u-boot.bin \
    $LOADER_OUT/uboot_rk.img $CONFIG_UBOOT_TEXT_BASE

echo "Making trust.img..."
cd $RKBIN_DIR && tools/trust_merger $CONFIG_ROCKCHIP_TRUST_INI
mv $RKBIN_DIR/trust.img $LOADER_OUT/trust.img

echo "Making loaders.img..."

rm -f $LOADER_OUT/loaders.img
dd if=$LOADER_OUT/idbloader.img of=$LOADER_OUT/loaders.img conv=notrunc
dd if=$LOADER_OUT/uboot_rk.img of=$LOADER_OUT/loaders.img seek=$(( 16384 - 64 )) conv=notrunc
dd if=$LOADER_OUT/trust.img of=$LOADER_OUT/loaders.img seek=$(( 24576 - 64 )) conv=notrunc

echo "Written to $LOADER_OUT/loaders.img"
