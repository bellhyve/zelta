#!/bin/sh

#set -x

#. spec/lib/exec_cmd.sh

exec_cmd() {
    if [ "${EXEC_CMD_QUIET:-}" != "1" ]; then
        printf '%s' "$*"
    fi
    if "$@"; then
        [ "${EXEC_CMD_QUIET:-}" != "1" ] && printf ' :* succeeded\n'
        return 0
    else
        _exit_code=$?
        [ "${EXEC_CMD_QUIET:-}" != "1" ] && printf ' :! failed (exit code: %d)\n' "$_exit_code"
        return "$_exit_code"
    fi
}

#x_exec_cmd() {
#    %putsn "$ $*"
#    if "$@"; then
#        %putsn "  -> succeeded"
#        return 0
#    else
#        _exit_code=$?
#        %putsn "  -> failed (exit code: $_exit_code)"
#        return "$_exit_code"
#    fi
#}

#exec_cmd() {
#    :;
#}

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
export ZELTA_BIN="$TEST_INSTALL/bin"
export ZELTA_SHARE="$TEST_INSTALL/share/zelta"
export ZELTA_ETC="$TEST_INSTALL/zelta"
export ZELTA_MAN8="$TEST_INSTALL/share/man/man8"


# Default devices if not set
: ${SRC_POOL_DEVICES:="/dev/nvme1n1"}
: ${TGT_POOL_DEVICES:="/dev/nvme2n1"}

export SRC_POOL_DEVICES
export TGT_POOL_DEVICES

export SRC_POOL='apool'
export TGT_POOL='bpool'
export TREETOP_DSN='treetop'
export BACKUPS_DSN='backups'

export ZELTA_ZFS_STORE_TEST_DIR="${LOCAL_TMP}/zelta-zfs-store-test"
export ZELTA_ZFS_TEST_POOL_SIZE="20G"

export SRC_TREE="$SRC_POOL/$TREETOP_DSN"
export TGT_TREE="$TGT_POOL/$BACKUPS_DSN/$TREETOP_DSN"
export ALL_DATASETS="one/two/three"

export BACKUP_USER="${SUDO_USER:-$(whoami)}"

check_zfs_installed

#export ZELTA_AWK="mawk -Wi"
export ZELTA_AWK=mawk

export PATH="${ZELTA_BIN}:$PATH"

#export EXEC_CMD_QUIET=1
#set +x
#true
