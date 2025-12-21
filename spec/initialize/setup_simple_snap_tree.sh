#!/bin/bash

#. spec/lib/exec_cmd.sh

DATASETS=(
    "$SRC_TREE"
    "$TGT_TREE"
)

dataset_exists() {
    zfs list "$1" &>/dev/null
    return $?
}

#create_tree_via_zfs() {
#    exec_cmd sudo zfs create -vp "$SRC_TREE"
#    exec_cmd sudo zfs create -vp "$SRC_TREE/$ALL_DATASETS"
#    exec_cmd sudo zfs create -vp "$TGT_POOL/$BACKUPS_DSN"
#    #sudo zfs create -vsV 16G -o volmode=dev $SRCTREE'/vol1'
#}

create_tree_via_zfs() {
    zfs create -vp "$SRC_TREE"
    zfs create -vp "$SRC_TREE/$ALL_DATASETS"
    zfs create -vp "$TGT_POOL/$BACKUPS_DSN"
    #sudo zfs create -vsV 16G -o volmode=dev $SRCTREE'/vol1'
}


create_tree_via_zelta() {
    zelta backup "$SRC_POOL" "$TGT_POOL/$TREETOP_DSN/$ALL_DATASETS"
    zelta revert "$TGT_POOL/$TREETOP_DSN"
    zelta backup "$TGT_POOL/$TREETOP_DSN" "$SRC_POOL/$TREETOP_DSN"
}

#rm_test_datasets() {
#    for dataset in "${DATASETS[@]}"; do
#        if zfs list "$dataset" &>/dev/null; then
#            echo "Destroying $dataset..."
#            exec_cmd sudo zfs destroy -vR "$dataset"
#        else
#            echo "Skipping $dataset (does not exist)"
#        fi
#    done
#}

rm_test_datasets() {
    for dataset in "${DATASETS[@]}"; do
        if zfs list "$dataset" &>/dev/null; then
            echo "Destroying $dataset..."
            zfs destroy -vR "$dataset"
        else
            echo "Skipping $dataset (does not exist)"
        fi
    done
}

setup_simple_snap_tree() {
    #set -x
    echo "Make a fresh test tree"
    rm_test_datasets
    create_tree_via_zfs
    # TODO: create via zelta
    #create_tree_via_zelta
    #setup_zfs_allow

    TREE_STATUS=$?
    #set +x
    #true
    return $TREE_STATUS
}

setup_simple_snap_tree
#STATUS=$?
#echo "status: $STATUS"
