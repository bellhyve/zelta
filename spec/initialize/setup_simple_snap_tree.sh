#!/bin/bash

. spec/lib/exec_cmd.sh

DATASETS=(
    "$SRC_TREE"
    "$TGT_TREE"
)

dataset_exists() {
    zfs list "$1" &>/dev/null
    return $?
}

create_tree_via_zfs() {
    sudo zfs create -vp "$SRC_TREE"
    sudo zfs create -vp "$SRC_TREE/$ALL_DATASETS"
    sudo zfs create -vp "$TGT_POOL/$BACKUPS_DSN"
    #sudo zfs create -vsV 16G -o volmode=dev $SRCTREE'/vol1'
}

create_tree_via_zelta() {
    zelta backup "$SRC_POOL" "$TGT_POOL/$TREETOP_DSN/$ALL_DATASETS"
    zelta revert "$TGT_POOL/$TREETOP_DSN"
    zelta backup "$TGT_POOL/$TREETOP_DSN" "$SRC_POOL/$TREETOP_DSN"
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

#exec_cmd() {
#    cmd=$*
#    echo -n "$cmd"
#    if $cmd; then
#        echo " :* succeeded"
#    else
#        echo " :! failed"
#        return 1
#    fi
#}

setup_zfs_allow() {
    SRC_ZFS_CMDS="send,snapshot,hold,bookmark,create,readonly,receive,volmode"
    TGT_ZFS_CMDS="send,snapshot,hold,bookmark,create,readonly,receive,volmode"
    exec_cmd sudo zfs allow -u "$BACKUP_USER" "$SRC_ZFS_CMDS" "$SRC_POOL"
    exec_cmd sudo zfs allow -u "$BACKUP_USER" "$TGT_ZFS_CMDS" "$TGT_POOL"
}

setup_simple_snap_tree() {
    #set -x
    echo "Make a fresh test tree"
    rm_test_datasets
    create_tree_via_zfs
    # TODO: create via zelta
    #create_tree_via_zelta
    setup_zfs_allow

    TREE_STATUS=$?
    #set +x
    #true
    return $TREE_STATUS
}

setup_simple_snap_tree
#STATUS=$?
#echo "status: $STATUS"
