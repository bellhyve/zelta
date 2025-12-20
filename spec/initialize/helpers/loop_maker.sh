#!/bin/sh

. ./spec/initialize/test_env.sh

set -x

cleanup_loop_img() {
    pool=$1
    img=$2
    # remove the pool
    sudo zpool destroy -f "$pool" 2>/dev/null || true

    # Detach all loops using this image
    sudo losetup -j "$img" | cut -d: -f1 | xargs -r sudo losetup -d

    rm -f "$img"
}

create_pool_from_loop_device() {
    pool=$1
    img="$ZELTA_ZFS_STORE_TEST_DIR/${pool}.img"
    cleanup_loop_img "$pool" "$img"
    truncate -s "$ZELTA_ZFS_TEST_POOL_SIZE" "$img"
    echo "created image file:"
    ls -lh $img

    # create loop device
    sudo losetup -f "$img"
    loop_device=$(losetup --list --noheadings --output NAME --associated "$img")

    echo "created loop_device:{$loop_device} for image file:{$img}"
    sudo zpool create -f -m "/${pool}" "${pool}" "${loop_device}"
}


setup_loop_img "${SRC_POOL}"

setup_loop_img "${TGT_POOL}"


set +x