#!/bin/bash

source configs/common

# -c: create
# -a: apply
OPT=$1
TARGET=$2

usage () {
    cat <<EOF
Usage: ./patch [-c|-a] [target dir]
Options:
    -c  create patch
    -a  apply patch
EOF
}

create_patch () {
    local SEARCHDIR=$TARGET
    local REPOS=$(find $SEARCHDIR -maxdepth 2 -type f -name ".git" -exec dirname {} \;)

    mkdir -p $SEARCHDIR/patch

    for repo in $REPOS; do
        local name=$(basename $repo)
        local baserev=$(git ls-tree HEAD $repo | awk '{ print $3 }')

        echo "Repo name: $name"
        echo "Base revision: $baserev"
        
        if [[ "$(git submodule status $repo | awk '{ print $1 }')" == \+* ]]; then
            echo "Found new commits, creating patch..."

            mkdir -p ./patch/$name
            local outdir=$(realpath ./patch/$name)
            local head=$(git rev-parse HEAD)

            pushd $repo >/dev/null
            echo "Enter repo $repo"
            git format-patch --output-directory $outdir $baserev | xargs -I {} sh -c '_n=$(basename {}); echo $_n;' > $outdir/PATCH.txt
            git reset $baserev
            git stash push -m "saved_$head"
            echo "Leave repo $repo"
            popd >/dev/null
        fi
    done
}

apply_patch () {
    local repo=$TARGET
    local name=$(basename $repo)

    if [[ -f "$PATCH_DIR/$name/PATCH.txt" ]]; then
        echo "Found: $PATCH_DIR/$name/PATCH.txt"
        echo "Now try to apply patch"

        while IFS= read -r patchname;do
            local patchfile=$(realpath -s --relative-to="$repo" $PATCH_DIR/$name/$patchname)
            echo "Patch file: $patchfile"
            
            pushd $repo >/dev/null
            git am $patchfile
            if [ "$?" != "0" ]; then
                echo "Apply patch failed, please check the status of \"$repo\""
                git am --abort
                exit 1
            fi
            popd >/dev/null
        done < "$PATCH_DIR/$name/PATCH.txt"
    fi
}

if [ "$#" -lt "2" ]; then
    echo "Invalid parameters"
    usage
    exit 1
fi

if [ "$OPT" == "-c" ]; then
    create_patch
    exit 0
fi

if [ "$OPT" == "-a" ]; then
    apply_patch
    exit 0
fi

echo "Invalid operation \"$OPT\""
usage
exit 1
