#!/bin/sh

. spec/lib/common.sh

check_pool_exists() {
    pool_name="$1"
    if [ -z "$pool_name" ]; then
        echo "** Error: Pool name required" >&2
        return 1
    fi
    exec_cmd sudo zpool list "$pool_name" >/dev/null 2>&1
}

destroy_pool_if_exists() {
    pool_name="$1"
    if check_pool_exists "$pool_name"; then
        echo "Destroying pool '$pool_name'..."
        exec_cmd sudo zpool list "$pool_name"
        if ! exec_cmd sudo zpool destroy -f "$pool_name"; then
            echo "Destroy for pool '$pool_name' failed, trying export then destroy"
            # Export is only needed when the pool is busy/imported but destroy can't complete
            exec_cmd sudo zpool export -f "$pool_name" && exec_cmd sudo zpool destroy -f "$pool_name"
        fi
    else
        echo "Pool '$pool_name' does not exist, no need to destroy"
    fi
}

rm_img_and_its_loop_devices() {
    img=$1
    echo "removing loop devices associated with image file: {$img}"
    exec_cmd sudo losetup -j "$img" | cut -d: -f1 | xargs -r exec_cmd sudo losetup -d

    echo "removing image file: {$img}"
    exec_cmd sudo rm -f "$img"
}

create_file_img() {
    pool_file_img=$1

    echo "Creating ${ZELTA_ZFS_TEST_POOL_SIZE}" "${pool_file_img}"
    truncate -s "${ZELTA_ZFS_TEST_POOL_SIZE}" "${pool_file_img}"

    echo "showing created file image:"
    ls -lh "${pool_file_img}"
}

create_pool_from_loop_device() {
    pool_name=$1
    pool_file_img="${ZELTA_ZFS_STORE_TEST_DIR}/${pool_name}.img"

    rm_img_and_its_loop_devices "$pool_file_img"

    create_file_img "$pool_file_img"

    echo "create loop device for file image: {$pool_file_img}"
    exec_cmd sudo losetup -f "$pool_file_img"

    loop_device=$(losetup --list --noheadings --output NAME --associated "$pool_file_img")
    echo "created loop_device:{$loop_device} for image file:{$pool_file_img}"

    echo "create pool {$pool_name} for loop device {$loop_device}"
    exec_cmd sudo zpool create -f -m "/${pool_name}" "${pool_name}" "${loop_device}"

}

create_pool_from_image_file() {
    pool_name=$1
    pool_file_img="${ZELTA_ZFS_STORE_TEST_DIR}/${pool_name}.img"

    create_file_img "$pool_file_img"
    echo "Creating zfs pool {$pool_name} from image file {$pool_file_img}"
    exec_cmd sudo zpool create -f -m "/${pool_name}" "${pool_name}" "${pool_file_img}"
}

create_test_pool() {
    pool_name="$1"
    if ! destroy_pool_if_exists "${pool_name}"; then
        echo "** Error: Can't delete pool {$pool_name}" >&2
        return 1
    fi

    if [ "$POOL_TYPE" = "$LOOP_DEV_POOL" ]; then
        create_pool_from_loop_device "$pool_name"
    elif [ "$POOL_TYPE" = "$FILE_IMG_POOL" ]; then
        create_pool_from_image_file $pool_name
    else
        echo "Can't create pools for unsupported POOL_TYPE: {$POOL_TYPE}" >&2
        return 1
    fi

    echo "Created ${pool_name}"
    exec_cmd sudo zpool list -v "${pool_name}"
}


#cleanup_loop_img() {
#    pool=$1
#    img=$2
#    # remove the pool
#    sudo zpool destroy -f "$pool" 2>/dev/null || true
#
#    # Detach all loops using this image
#    sudo losetup -j "$img" | cut -d: -f1 | xargs -r sudo losetup -d
#
#    rm -f "$img"
#}


verify_pool_creation() {
    pool_name="$1"
    expected_size="$2"

    if check_pool_exists "$pool_name"; then
        actual_size=$(exec_cmd sudo zpool list -H -o size "$pool_name")
        echo "Success: Pool '$pool_name' created successfully. Size: $actual_size (Expected: $expected_size)"
    else
        echo "Error: Pool '$pool_name' was NOT created."
        return 1
    fi
}

create_pools() {
    echo ""
    echo "=== create pool ${SRC_POOL} ==="
    create_test_pool "${SRC_POOL}"
    SRC_STATUS=$?
    echo ""
    echo "=== create pool ${TGT_POOL} ==="
    create_test_pool "${TGT_POOL}"
    TGT_STATUS=$?

    echo "SRC_STATUS:{$SRC_STATUS}"
    echo "TGT_STATUS:{$TGT_STATUS}"

    return $((SRC_STATUS || TGT_STATUS))
}


mkdir -p "${ZELTA_ZFS_STORE_TEST_DIR}"
create_pools
setup_zfs_allow

#setup_loop_img "${SRC_POOL}"
#setup_loop_img "${TGT_POOL}"


