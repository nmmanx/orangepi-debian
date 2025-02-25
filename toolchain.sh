#!/bin/bash

source configs/common

TOOLCHAIN_DIR=$OUTDIR/toolchain

# Linaro GCC
# GCC_NAME=gcc-linaro-13.0.0-2022.11-x86_64_aarch64-linux-gnu
# GCC_LINK=https://snapshots.linaro.org/gnu-toolchain/13.0-2022.11-1/aarch64-linux-gnu/gcc-linaro-13.0.0-2022.11-x86_64_aarch64-linux-gnu.tar.xz

# ARM GCC
GCC_NAME=arm-gnu-toolchain-13.2.Rel1-x86_64-aarch64-none-linux-gnu
GCC_LINK=https://armkeil.blob.core.windows.net/developer/Files/downloads/gnu/13.2.rel1/binrel/arm-gnu-toolchain-13.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz

GCC_ARCHIVE_FILE=$TOOLCHAIN_DIR/$(basename ${GCC_LINK})

# export CROSS_COMPILE_PREFIX=${TOOLCHAIN_DIR}/${GCC_NAME}/bin/aarch64-linux-gnu-
export CROSS_COMPILE_PREFIX=${TOOLCHAIN_DIR}/${GCC_NAME}/bin/aarch64-none-linux-gnu-

prepare_toolchain () {
    mkdir -p $TOOLCHAIN_DIR

    if [ ! -f "$GCC_ARCHIVE_FILE" ]; then
        echo "Downloading compiler..."
        wget -O $GCC_ARCHIVE_FILE $GCC_LINK
    fi

    echo "Downloaded: $GCC_ARCHIVE_FILE"
    
    if [ ! -f "${CROSS_COMPILE_PREFIX}gcc" ]; then
        echo "Extracting..."
        tar -xf $GCC_ARCHIVE_FILE -C $TOOLCHAIN_DIR
    fi

    echo "Extracted to: $TOOLCHAIN_DIR"
}

prepare_toolchain

echo CROSS_COMPILE_PREFIX=$CROSS_COMPILE_PREFIX

test -f ${CROSS_COMPILE_PREFIX}gcc
