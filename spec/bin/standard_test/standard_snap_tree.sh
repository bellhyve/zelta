#!/bin/sh

. spec/bin/standard_test/standard_test_env.sh

DATASETS="${SRC_TREE} ${TGT_TREE}"

dataset_exists() {
    exec_cmd zfs list "$1" &>/dev/null
    return $?
}

#create_tree_via_zfs() {
#    exec_cmd sudo zfs create -vp "$SRC_TREE"
#    exec_cmd sudo zfs create -vp "$SRC_TREE/$ALL_DATASETS"
#    exec_cmd sudo zfs create -vp "$TGT_POOL/$BACKUPS_DSN"
#    #sudo zfs create -vsV 16G -o volmode=dev $SRCTREE'/vol1'
#}

#export SRC_TREE="$SRC_POOL/$TREETOP_DSN"
#export TGT_TREE="$TGT_POOL/$BACKUPS_DSN/$TREETOP_DSN"

#try1_create_test_tree() {
#    local pool="$1"
#    local root="$2"
#    local mount_base="$3"
#
#    mkdir -p "${mount_base}/${root}/one/two/three"
#    zfs create -o mountpoint="${mount_base}/${root}" "${pool}/${root}"
#    zfs create -o mountpoint="${mount_base}/${root}/one" "${pool}/${root}/one"
#    zfs create -o mountpoint="${mount_base}/${root}/one/two" "${pool}/${root}/one/two"
#    zfs create -o mountpoint="${mount_base}/${root}/one/two/three" "${pool}/${root}/one/two/three"
#
#    echo "Test tree created successfully"
#    echo "Mounted at: $mount_base"
#}


new_create_tree_via_zfs() {
    #exec_cmd zfs create -o mountpoint="${mount_base}/$TREETOP_DSN} -vp "$SRC_TREE"
    mkdir -p "${ZFS_MOUNT_BASE}/${TREETOP_DSN}"
    mkdir -p "${ZFS_MOUNT_BASE}/${BACKUPS_DSN}"
    exec_cmd echo zfs create -o mountpoint="${ZFS_MOUNT_BASE}/${TREETOP_DSN}" -vp "$SRC_POOL/$TREETOP_DSN"
    #exec_cmd echo zfs create -o mountpoint="${ZFS_MOUNT_BASE}/${TREETOP_DSN}" -vp "$SRC_POOL/$TREETOP_DSN"
    #$SRC_TREE/$ALL_DATASETS"
    exec_cmd echo zfs create -o mountpoint="${ZFS_MOUNT_BASE}/${BACKUPS_DSN}" -vp "$TGT_POOL/$BACKUPS_DSN"
    #sudo zfs create -vsV 16G -o volmode=dev $SRCTREE'/vol1'
}

old_create_tree_via_zfs() {
    exec_cmd sudo zfs create -vp "$SRC_TREE"
    exec_cmd sudo zfs create -vp "$SRC_TREE/$ALL_DATASETS"
    exec_cmd sudo zfs create -vp "$TGT_POOL/$BACKUPS_DSN"
    #sudo zfs create -vsV 16G -o volmode=dev $SRCTREE'/vol1'
}


create_tree_via_zelta() {
    exec_cmd zelta backup "$SRC_POOL" "$TGT_POOL/$TREETOP_DSN/$ALL_DATASETS"
    exec_cmd zelta revert "$TGT_POOL/$TREETOP_DSN"
    exec_cmd zelta backup "$TGT_POOL/$TREETOP_DSN" "$SRC_POOL/$TREETOP_DSN"
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

rm_all_datasets_for_pool() {
    poolname=$1

    # shellcheck disable=SC2120
    reverse_lines() {
        awk '{lines[NR]=$0} END {for(i=NR;i>0;i--) print lines[i]}' "$@"
    }

    echo "removing all datasets for pool {$poolname}"
    dataset_list=$(zfs list -H -o name -t filesystem,volume -r $poolname | grep -v "^${poolname}$" | reverse_lines)
    echo $dataset_list

    zfs list -H -o name -t filesystem,volume -r $poolname | grep -v "^${poolname}\$" | reverse_lines | while IFS= read -r dataset; do
        exec_cmd sudo zfs destroy -r "$dataset"
    done

}

x_rm_test_datasets() {
    for dataset in $DATASETS; do
    #for dataset in 'apool'; do
        if dataset_exists "$dataset"; then
            echo "found dataset, please delete it"
        else
            echo "there is no dataset to remove "
        fi

        if exec_cmd sudo zfs list "$dataset" &>/dev/null; then
            #echo "Destroying $dataset..."
            echo "need to destroy dataset $dataset"
            #exec_cmd zfs destroy -vR "$dataset"
        else
            echo "Skipping $dataset (does not exist)"
        fi
    done
}

setup_simple_snap_tree() {
    #set -x
    echo "Make a fresh test tree"
    #rm_test_datasets
    rm_all_datasets_for_pool $SRC_POOL
    rm_all_datasets_for_pool $TGT_POOL
    #new_create_tree_via_zfs
    #try1_create_test_tree "$SRC_POOL" "$TREETOP_DSN" "$ZFS_MOUNT_BASE"
    old_create_tree_via_zfs

    # TODO: create via zelta
    #create_tree_via_zelta
    #setup_zfs_allow

    TREE_STATUS=$?
    #set +x
    #true
    return $TREE_STATUS
}


#set -x
setup_simple_snap_tree
#set +x

#STATUS=$?
#echo "status: $STATUS"
