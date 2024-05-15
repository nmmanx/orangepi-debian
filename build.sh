#!/bin/bash

source configs/common

show_help () {
    cat <<EOF
Build a Debian image for Orange Pi Boards
Usage: build.sh [OPTIONS] [TARGET]

OPTIONS:
    -c, --clean-root     Re-generate root file system (only generate once by default)
    -l, --list           List all supported boards
    -h, --help           Show this help
EOF
}

list_boards () {
    local dirs=$(find ./configs -maxdepth 1 -mindepth 1 -type d)
    echo "Found boards:"
    for d in $dirs; do
        local name=$(grep -oP '(?<=CONFIG_BOARD_NAME=").+[^\"]' $d/config)
        local i=1
        if [ -n "$name" ]; then
            echo $i. $(basename $d) \($name\)
            i=$(($i + 1))
        fi
    done
}

TARGET=${@: -1}
OPTS=${@:1:$(($# - 1))}

if [[ ! "$#" > "0" ]] || [[ -z "$TARGET" ]]; then
    echo "Missing target"
    show_help
    exit 1
fi

GETOPT_ARGS=$(getopt -o c,l,h --long clean-root,list,help -- "$OPTS")
if [ "$?" != "0" ]; then
    echo "Invalid arguments"
    show_help
    exit 1;
fi

OPT_CLEAN_ROOT=1

# Don't regenerate rootfs everytime
if [ -f "$ROOTFS/etc/apt/sources.list" ]; then
    OPT_CLEAN_ROOT=0
fi

while [ : ]; do
  case "$1" in
    -c | --clean-root)
        OPT_CLEAN_ROOT=1
        shift
        ;;
    -l | --list)
        list_boards
        exit 0
        ;;
    -h | --help)
        show_help
        exit 0
        ;;
    *) shift; 
        break 
        ;;
  esac
done

BOARD_NAME=$(grep -oP '(?<=CONFIG_BOARD_NAME=").+[^\"]' configs/${TARGET}/config 2>/dev/null)
if [ -z "$BOARD_NAME" ]; then
    echo "Invalid board: \"$TARGET\""
    echo "Run \"build.sh -l\" for listing supported boards"
    exit 1
fi

source configs/${TARGET}/config

echo "Selected board: $TARGET (${BOARD_NAME})"
echo "Re-generate rootfs: $(one2true $OPT_CLEAN_ROOT)"

mkdir -p $OUTDIR/logs
exec 3>&1

_ret=0

echo "===== PATCH ====="

./patch.sh -a $UBOOT_DIR

echo "===== BUILD ====="

./build_loaders.sh $TARGET 3>&1 > $OUTDIR/logs/build_loaders.sh.log 2>&1
term_on_failed $? "Build bootloaders failed, check $OUTDIR/logs/build_loaders.sh.log"

echo "Done"
exit 0