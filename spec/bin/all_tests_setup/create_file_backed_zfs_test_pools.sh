#!/bin/sh

. spec/lib/common.sh

pool_image_file() {
    pool_name=$1
    echo "${ZELTA_ZFS_STORE_TEST_DIR}/${pool_name}.img" # return value is output to stdout
}


md_unit_file() {
    pool_name=$1
    echo "${ZELTA_ZFS_STORE_TEST_DIR}/${pool_name}.md" # return value is output to stdout
}


create_freebsd_mem_disk_pool() {
    pool_name=$1
    img_file=$(pool_image_file $pool_name)
    create_file_img $img_file

    # Attach as memory disk
    md_unit=$(mdconfig -a -t vnode -f "$img_file")
    echo "Created $md_unit for $pool_name"

    # Create pool on the device
    exec_cmd sudo zpool create "$pool_name" "/dev/$md_unit"

    # Store md unit for cleanup
    #echo "$md_unit" > "/tmp/${pool_name}.md"
    md_file=$(md_unit_file "$pool_name")
    echo "$md_unit" > "$md_file"
}

## Destroy image-backed pool on FreeBSD
destroy_freebsd_mem_disk_pool() {
    pool_name=$1
    img_file=$(pool_image_file "$pool_name")

    #img_file="/tmp/${pool_name}.img"
    #img_file=$img_file
    #md_file="/tmp/${pool_name}.md"
    md_file=$(md_unit_file "$pool_name")

#    destroy_pool_if_exists "$pool_name"
#    # Destroy pool
#    if exec_cmd sudo zpool list "$pool_name" >/dev/null 2>&1; then
#        exec_cmd sudo zpool export "$pool_name" || zpool destroy -f "$pool_name"
#    fi

    # Detach md device
    if [ -f "$md_file" ]; then
        md_unit=$(cat "$md_file")
        mdconfig -d -u "${md_unit#md}"
        rm "$md_file"
    fi

    # Remove image file
    rm -f "$img_file"
}

create_freebsd_test_pool() {
    pool_name=$1
    echo_alert "running create_freebsd_test_pool - pool_name {$pool_name}"
    destroy_freebsd_mem_disk_pool $pool_name
    create_freebsd_mem_disk_pool $pool_name
}



check_pool_exists() {
    pool_name="$1"
    if [ -z "$pool_name" ]; then
        echo "** Error: Pool name required" >&2
        return 1
    fi
    exec_cmd sudo zpool list "$pool_name" >/dev/null 2>&1
}



destroy_pool() {
    pool_name=$1
    echo "Destroying pool '$pool_name'..."
    if exec_cmd sudo zpool export -f "$pool_name"; then
        # TODO: the export seems to remove the pool and then zpool destory fails
        # TODO: research this
        exec_cmd sudo zpool destroy -f "$pool_name"

    fi

    # since the above isn't working as expected, we check if the pool
    # still exists and return an error if it does
    if check_pool_exists $pool_name; then
        return 1
    fi

    # forcing this to return 0 because of the above
    #return 0

#    if ! exec_cmd sudo zpool destroy -f "$pool_name"; then
#        echo "Destroy for pool '$pool_name' failed, trying export then destroy"
#        # Export is only needed when the pool is busy/imported but destroy can't complete
#        exec_cmd sudo zpool export -f "$pool_name" && exec_cmd sudo zpool destroy -f "$pool_name"
#    fi
}

## 1. Export (destroy) the pool
#zfs destroy -r poolname  # destroys all datasets (optional, if you want to be thorough)
#zpool destroy poolname   # destroys the pool itself
#
## 2. Detach the loop device
#sudo losetup -d /dev/loop0  # replace loop0 with your actual loop device





destroy_pool_if_exists() {
    pool_name="$1"
    if check_pool_exists "$pool_name"; then
         destroy_pool "$pool_name"
    else
        echo "Pool '$pool_name' does not exist, no need to destroy"
    fi
}

rm_img_and_its_loop_devices() {
    img=$1
    echo "removing loop devices associated with image file: {$img}"

    # Remove all loop devices at once
    sudo losetup -j "$img" | cut -d: -f1 | xargs -r -n1 sudo losetup -d

    echo "removing image file: {$img}"
    exec_cmd sudo rm -f "$img"
}

#x2rm_img_and_its_loop_devices() {
#    img=$1
#    echo "removing loop devices associated with image file: {$img}"
#
#    # Get all loop devices for this image
#    while IFS= read -r loop_device; do
#        if [[ -n "$loop_device" ]]; then
#            echo "removing loop device {$loop_device}"
#            exec_cmd sudo losetup -d "$loop_device"
#        fi
#    done < <(sudo losetup -j "$img" | cut -d: -f1)
#
#    echo "removing image file: {$img}"
#    exec_cmd sudo rm -f "$img"
#}

#xxrm_img_and_its_loop_devices() {
#    img=$1
#    echo "removing loop devices associated with image file: {$img}"
#    #exec_cmd sudo losetup -j "$img" | cut -d: -f1 | xargs -r exec_cmd sudo losetup -d
#
#    loop_device=$(sudo losetup -j "$img" | cut -d: -f1)
#    echo "removing loop device {$loop_device}"
#    exec_cmd sudo losetup -d $loop_device
#    echo "removing image file: {$img}"
#    exec_cmd sudo rm -f "$img"
#}

create_file_img() {
    img_file=$1

    # NOTE: important to remove the image file first so that all zfs metadata is removed.
    # truncate on an existing file will resize it and leave the metadata in place leading to crashes
    rm -f "${img_file}"

    echo "Creating ${ZELTA_ZFS_TEST_POOL_SIZE}" "${img_file}"
    truncate -s "${ZELTA_ZFS_TEST_POOL_SIZE}" "${img_file}"

    echo "showing created file image:"
    ls -lh "${img_file}"
}
# old name
#create_pool_from_loop_device()

create_linux_loop_device_pool() {
    pool_name=$1

    echo_alert "running create_linux_loop_device_pool - pool {$pool_name}"

    img_file=$(pool_image_file $pool_name)

    rm_img_and_its_loop_devices "$img_file"

    create_file_img "$img_file"

    echo "create loop device for file image: {$img_file}"
    exec_cmd sudo losetup -f "$img_file"

    loop_device=$(losetup --list --noheadings --output NAME --associated "$img_file")
    echo "created loop_device:{$loop_device} for image file:{$img_file}"

    echo "create pool {$pool_name} for loop device {$loop_device}"
    exec_cmd sudo zpool create -f -m "/${pool_name}" "${pool_name}" "${loop_device}"
}

create_pool_from_image_file() {
    pool_name=$1
    img_file=$(pool_image_file $pool_name)

    create_file_img "$img_file"
    echo "Creating zfs pool {$pool_name} from image file {$img_file}"
    exec_cmd sudo zpool create -f -m "/${pool_name}" "${pool_name}" "${img_file}"
}

create_test_pool() {
    pool_name="$1"
    if ! destroy_pool_if_exists "${pool_name}"; then
        echo "** Error: Can't delete pool {$pool_name}" >&2
        return 1
    fi

    if [ "$POOL_TYPE" = "$MEMORY_DISK_POOL" ]; then
        create_freebsd_test_pool $pool_name
    elif [ "$POOL_TYPE" = "$LOOP_DEV_POOL" ]; then
        create_linux_loop_device_pool "$pool_name"
    elif [ "$POOL_TYPE" = "$FILE_IMG_POOL" ]; then
        create_pool_from_image_file $pool_name
    else
        echo "Can't create pools for unsupported POOL_TYPE: {$POOL_TYPE}" >&2
        return 1
    fi

    echo "Created ${pool_name}"
    exec_cmd sudo zpool list -v "${pool_name}"
}


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
set -x
rm -fR "${ZFS_MOUNT_BASE}"
mkdir -p "${ZFS_MOUNT_BASE}"
chmod 777 "${ZFS_MOUNT_BASE}"
chown ${BACKUP_USER} "${ZFS_MOUNT_BASE}"
chgrp ${BACKUP_USER} "${ZFS_MOUNT_BASE}"

ls -ld "${ZFS_MOUNT_BASE}"
mkdir -p "${ZELTA_ZFS_STORE_TEST_DIR}"

create_pools
setup_zfs_allow

set +x
#setup_loop_img "${SRC_POOL}"
#setup_loop_img "${TGT_POOL}"


