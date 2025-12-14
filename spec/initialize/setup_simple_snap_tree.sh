#!/bin/bash




DATASETS=(
    "$SRC_TREE"
    "$TGT_TREE"
)


dataset_exists() {
    zfs list "$1" &>/dev/null
    return $?
}




create_tree_via_zfs() {
    #SRC_TREE="$SRC_POOL/$TREETOP_DSN"
    #TGT_TREE="$TGT_POOL/$BACKUPS_DSN/$TREETOP_DSN"
    #DATASETS="one/two/three"

    sudo zfs create -vp $SRC_TREE
    sudo zfs create -vp "$SRC_TREE/$ALL_DATASETS"
    #sudo zfs create -vsV 16G -o volmode=dev $SRCTREE'/vol1'
}


create_tree_via_zelta() {
    #zelta backup $SRC_POOL $TGT_POOL/treetop/one/two/three
    set -x
    zelta backup $SRC_POOL $TGT_POOL/$TREETOP_DSN/$ALL_DATASETS
    zelta revert $TGT_POOL/$TREETOP_DSN
    zelta backup $TGT_POOL/$TREETOP_DSN  $SRC_POOL/$TREETOP_DSN
    set +x
}

rm_test_datasets() {
    for dataset in "${DATASETS[@]}"; do
        if zfs list "$dataset" &>/dev/null; then
            echo "Destroying $dataset..."
            sudo zfs destroy -vR "$dataset"
        else
            echo "Skipping $dataset (does not exist)"
        fi
    done
}

echo "Make a fresh test tree"
rm_test_datasets
#create_tree_via_zfs
create_tree_via_zelta


#zfs destroy -vR "$SRCTREE"
#zfs destroy -vR "$TGTTOP"
