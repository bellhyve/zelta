#!/bin/sh
set -x

remove_loop_devices_associated_with_image_file() {
    img=$1
    # List all loop devices bound to this image
    sudo losetup -j "$img"

    # Detach them
    sudo losetup -j "$img" | cut -d: -f1 | xargs -r sudo losetup -d
}

create_image_file_for_pool() {
    pool_name=$1
    pool_file_img="${ZELTA_ZFS_STORE_TEST_DIR}/${pool_name}.img"
    remove_loop_devices_associated_with_image_file "$pool_file_img"
    sudo rm -fr "$pool_file_img"

    echo "Creating ${ZELTA_ZFS_TEST_POOL_SIZE}" "${pool_file_img}"
    truncate -s "${ZELTA_ZFS_TEST_POOL_SIZE}" "${pool_file_img}"
    ls -lh "${pool_file_img}"
}

. ./spec/initialize/test_env.sh
sudo zpool destroy -f $SRC_POOL
sudo zpool destroy -f $TGT_POOL



sudo losetup -f "${pool_file_img}"

losetup -a | grep "${pool_file_img}"

#echo "Creating zfs pool $pool_name "

#sudo zpool create -f -m "/${pool_name}" "${pool_name}" "${pool_file_img}"

line=$(
  losetup -a | grep "${pool_file_img}"
)

loop_device=${line%%:*}

echo "loop_device:{$loop_device}"

set +x
#  grep '/home/dever/src/repos/bt/zelta/spec/tmp/zelta-zfs-store-test/bpool.img' /path/to/loopfile
