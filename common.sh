#!/bin/bash

if [ "$DOCKER" == "1" ]; then
MOUNTPOINT=/orangepi-debian
else
MOUNTPOINT=./
fi

OUTDIR=${MOUNTPOINT}/out
