#!/bin/sh

#set -x

check_zfs_installed() {
    # Check if zfs is already on PATH
    if ! command -v zfs >/dev/null 2>&1; then
        # Allow user to override ZFS_BIN location, default to /usr/local/sbin
        ZFS_BIN="${ZFS_BIN:-/usr/local/sbin}"

        # Add ZFS_BIN to PATH if not already present
        case ":$PATH:" in
        *":$ZFS_BIN:"*) ;;
        *) PATH="$ZFS_BIN:$PATH" ;;
        esac
        export PATH

        # Verify zfs command is now available
        if ! command -v zfs >/dev/null 2>&1; then
            echo "Error: zfs command not found. Please set ZFS_BIN to the correct location." >&2
            return 1
        fi
    fi
}

CUR_DIR=$(pwd)
#echo "$CUR_DIR"

export INITIALIZE_DIR="${CUR_DIR}/spec/initialize"

export LOCAL_TMP="${CUR_DIR}/spec/tmp"
export INITIALIZATION_COMPLETE_MARKER_FILE="$LOCAL_TMP/.initialize_testing_setup_complete"
export TEST_INSTALL="${LOCAL_TMP}/test_install"
# allow for custom zfs installation
# OpenZFS builds are typically installed in "/usr/local/sbin" for testing
export ZFS_BIN="${ZFS_BIN:-/usr/local/sbin}"
export ZELTA_BIN="$TEST_INSTALL/bin"
export ZELTA_SHARE="$TEST_INSTALL/share/zelta"
export ZELTA_ETC="$TEST_INSTALL/zelta"

export SRC_POOL='apool'
export TGT_POOL='bpool'
export TREETOP_DSN='treetop'
export BACKUPS_DSN='backups'

export ZELTA_ZFS_STORE_TEST_DIR="${LOCAL_TMP}/zelta-zfs-store-test"
export ZELTA_ZFS_TEST_POOL_SIZE="20G"

export SRC_TREE="$SRC_POOL/$TREETOP_DSN"
export TGT_TREE="$TGT_POOL/$BACKUPS_DSN/$TREETOP_DSN"
export ALL_DATASETS="one/two/three"

check_zfs_installed

#export PATH="${ZELTA_BIN}":"${ZFS_BIN}":/usr/bin:/bin
export PATH="${ZELTA_BIN}:$PATH"

#set +x
#true
