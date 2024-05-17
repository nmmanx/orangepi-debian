#!/bin/bash

source configs/common

TARGET=$1
if [ ! -d "./configs/$TARGET" ]; then
    echo "Invalid target: $TARGET"
    exit 1
fi
source configs/$TARGET/config

require_config CONFIG_ROCKCHIP_PLATFORM
require_config CONFIG_ROCKCHIP_DDR_BIN
require_config CONFIG_ROCKCHIP_MINILOADER
require_config CONFIG_ROCKCHIP_TRUST_INI
require_config CONFIG_UBOOT_TEXT_BASE

mkdir -p $LOADER_OUT

log "Making idbloader.img..."
cd $RKBIN_DIR && tools/mkimage -n $CONFIG_ROCKCHIP_PLATFORM \
    -T rksd -d $CONFIG_ROCKCHIP_DDR_BIN $LOADER_OUT/idbloader.img
cat $CONFIG_ROCKCHIP_MINILOADER >> $LOADER_OUT/idbloader.img

log "Making uboot_rk.img..."
cd $RKBIN_DIR && tools/loaderimage --pack --uboot $UBOOT_OUT/u-boot.bin \
    $LOADER_OUT/uboot_rk.img $CONFIG_UBOOT_TEXT_BASE

test ! "$?" -eq "0" && exit 1

log "Making trust.img..."
cd $RKBIN_DIR && tools/trust_merger $CONFIG_ROCKCHIP_TRUST_INI
mv $RKBIN_DIR/trust.img $LOADER_OUT/trust.img

log "Making loaders.img..."

rm -f $LOADER_OUT/loaders.img
dd if=$LOADER_OUT/idbloader.img of=$LOADER_OUT/loaders.img bs=$CONFIG_SD_BLOCK_SIZE conv=notrunc
dd if=$LOADER_OUT/uboot_rk.img of=$LOADER_OUT/loaders.img bs=$CONFIG_SD_BLOCK_SIZE seek=$(( 16384 - 64 )) conv=notrunc
dd if=$LOADER_OUT/trust.img of=$LOADER_OUT/loaders.img bs=$CONFIG_SD_BLOCK_SIZE seek=$(( 24576 - 64 )) conv=notrunc

log "Written to $LOADER_OUT/loaders.img"

exit 0
