#!/bin/sh

ZELTA_ZFS_STORE_TEST_DIR="$HOME/zelta-zfs-store-test"
ZELTA_ZFS_TEST_POOL_SIZE="20G"

APOOL_NAME=apool
BPOOL_NAME=bpool

#APOOL_IMG=${ZELTA_ZFS_STORE_TEST_DIR}/apool.img
#BPOOL_IMG=${ZELTA_ZFS_STORE_TEST_DIR}/bpool.img

check_pool_exists() {
    pool_name="$1"
    if [ -z "$pool_name" ]; then
        echo "Error: Pool name required" >&2
        return 1
    fi
    sudo zpool list "$pool_name" > /dev/null 2>&1
}

destroy_pool_if_exists() {
    #set -x
    pool_name="$1"
    if check_pool_exists "$pool_name"; then
        echo "Destroying pool '$pool_name'..."
        sudo zpool list "$pool_name"
        sudo zpool export "$pool_name"
        sudo zpool import "$pool_name"

         #sudo zpool destroy "$pool_name"
         #sudo zfs umount -a "$pool_name"
        sudo zpool destroy -f "$pool_name"
        sudo zpool list "$pool_name"
        return $?
    else
        echo "Pool '$pool_name' does not exist., no need to destroy"
        return 1
    fi
    #set +x
    #true
}

create_test_pool() {
    #set -x
    pool_name="$1"
    destroy_pool_if_exists "${pool_name}"

    pool_file_img="${ZELTA_ZFS_STORE_TEST_DIR}/${pool_name}.img"
    echo "Creating ${ZELTA_ZFS_TEST_POOL_SIZE}" "${pool_file_img}"
    truncate -s "${ZELTA_ZFS_TEST_POOL_SIZE}" "${pool_file_img}"
    ls -lh "${pool_file_img}"
    echo "Creating zfs pool $pool_name "

    sudo zpool create -f -m "/${pool_name}" "${pool_name}" "${pool_file_img}"
    #echo zpool create -f -m "/${pool_name}" "${pool_name}" "${pool_file_img}"
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
    #set -x
    echo ""
    echo "=== create pool ${APOOL_NAME} ==="
    create_test_pool ${APOOL_NAME}

    echo ""
    echo "=== create pool ${BPOOL_NAME} ==="
    create_test_pool ${BPOOL_NAME}
#
#  echo ""
#  echo "=== pools created ==="
#  sudo zpool list "${APOOL_NAME}" "${BPOOL_NAME}"
#
#  echo ""
#  echo "=== Disk Usage on ${ZELTA_ZFS_STORE_TEST_DIR} ==="
#  df -h "${ZELTA_ZFS_STORE_TEST_DIR}"
#
#  echo ""
#  echo "=== Verifying Creation ==="
#  verify_pool_creation ${APOOL_NAME} ${ZELTA_ZFS_TEST_POOL_SIZE}
#  apool_status=$?
#
#  verify_pool_creation ${BPOOL_NAME} ${ZELTA_ZFS_TEST_POOL_SIZE}
#  bpool_status=$?
#  set +x
#
#  if [ "$apool_status" -ne 0 ] || [ "$bpool_status" -ne 0 ]; then
#      echo "CRITICAL ERROR: One or more pools failed to create properly."
#      exit 1
#  fi
   true
}

#set -x
#echo "hello: create_file_backed_zfs_test_pools.sh"
#return 0
create_pools
#return 0
#set +x
#true
#return 0

