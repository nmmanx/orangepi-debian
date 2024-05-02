#!/bin/bash

source toolchain.sh
if [ "$?" == "0" ]; then
    echo "Toolchain OK"
else
    echo "Missing toolchain!"
    exit 1
fi
