#!/bin/bash

CONFIG_UBOOT_DEFCONFIG="./configs/orangepi4_lts/uboot/orangepi4lts_defconfig"
CONFIG_UBOOT_EXTRA_MAKE_ARGS="BL31=$(realpath deps/rkbin/bin/rk33/rk3399_bl31_v1.36.elf)"
