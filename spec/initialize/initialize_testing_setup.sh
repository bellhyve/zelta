#!/bin/sh

. spec/initialize/test_env.sh
. spec/lib/common.sh

#exec_cmd printf "hello there\n"

verify_root() {
    # Check if running as root
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: You must run as root or with sudo" >&2
        return 1
    fi
}

initialize_zelta_test() {
    echo "-- BeforeAll setup"

    echo "-- installing zelta"
    "${INITIALIZE_DIR}"/install_local_zelta.sh
    INSTALL_STATUS=$?
    if [ $INSTALL_STATUS -ne 0 ]; then
        echo "** Error: zelta install failed"
    fi

    #"${INITIALIZE_DIR}"/create_device_backed_zfs_test_pools.sh
    #"${INITIALIZE_DIR}"/create_file_backed_zfs_test_pools.sh
    #TREE_STATUS=$?

#    echo "-- creating test pools"
    if "${INITIALIZE_DIR}"/create_file_backed_zfs_test_pools.sh; then
    #if "${INITIALIZE_DIR}"/create_device_backed_zfs_test_pools.sh; then
        echo "-- setting up snap tree"
        "${INITIALIZE_DIR}"/setup_simple_snap_tree.sh
        TREE_STATUS=$?
    else
        echo "** Error: failed to setup zfs pool" >&2
        TREE_STATUS=1
    fi

    #CREATE_STATUS=$?

    #echo "-- Create pool status:    {$CREATE_STATUS}"
    echo "-- Install Zelta status:  {$INSTALL_STATUS}"
    echo "-- Make snap tree status: {$TREE_STATUS}"

    #SETUP_STATUS=$((CREATE_STATUS || INSTALL_STATUS || TREE_STATUS))
    SETUP_STATUS=$((INSTALL_STATUS || TREE_STATUS))
    echo "-- returning SETUP_STATUS:{$SETUP_STATUS}"

    if [ $SETUP_STATUS -ne 0 ]; then
        echo "** Error: zfs pool and/or zelta install failed!" >&2
    fi

    return $SETUP_STATUS
}

if verify_root; then
   initialize_zelta_test
fi
