#!/bin/sh

check_pool_exists() {
    pool_name="$1"
    if [ -z "$pool_name" ]; then
        echo "** Error: Pool name required" >&2
        return 1
    fi
    sudo zpool list "$pool_name" > /dev/null 2>&1
}

destroy_pool_if_exists() {
    pool_name="$1"
    if check_pool_exists "$pool_name"; then
        echo "Destroying pool '$pool_name'..."
        sudo zpool list "$pool_name"
        if ! sudo zpool destroy -f "$pool_name"; then
            echo "Destroy for pool '$pool_name' failed, trying export then destroy"
            # Export is only needed when the pool is busy/imported but destroy can't complete
            sudo zpool export -f "$pool_name" && sudo zpool destroy -f "$pool_name"
        fi
    else
        echo "Pool '$pool_name' does not exist, no need to destroy"
    fi
}

create_test_pool() {
    #set -x
    pool_name="$1"
    if ! destroy_pool_if_exists "${pool_name}"; then
      echo "** Error: Can't delete pool {$pool_name}" >&2
      return 1
    fi

    pool_file_img="${ZELTA_ZFS_STORE_TEST_DIR}/${pool_name}.img"
    echo "Creating ${ZELTA_ZFS_TEST_POOL_SIZE}" "${pool_file_img}"
    truncate -s "${ZELTA_ZFS_TEST_POOL_SIZE}" "${pool_file_img}"
    ls -lh "${pool_file_img}"
    echo "Creating zfs pool $pool_name "

    sudo zpool create -f -m "/${pool_name}" "${pool_name}" "${pool_file_img}"

    echo "Created ${pool_name}"
    sudo zpool list "${pool_name}"
    #  set +x
    #true
}

verify_pool_creation() {
    pool_name="$1"
    expected_size="$2"

    if check_pool_exists "$pool_name"; then
        actual_size=$(sudo zpool list -H -o size "$pool_name")
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

    return $(( SRC_STATUS || TGT_STATUS ))
}

mkdir -p "${ZELTA_ZFS_STORE_TEST_DIR}"
create_pools
