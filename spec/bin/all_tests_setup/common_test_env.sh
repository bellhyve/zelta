#!/bin/sh

. spec/lib/common.sh

CUR_DIR=$(pwd)

. spec/bin/all_tests_setup/env_constants.sh

# backup username, should be configured for ssh access on remotes
export BACKUP_USER="${BACKUP_USER:-dever}"
#export BACKUP_USER="${SUDO_USER:-$(whoami)}"

# location for git pulls of source for testing
export ZELTA_GIT_CLONE_DIR="${ZELTA_GIT_CLONE_DIR:-/tmp/zelta-dev}"
export GIT_TEST_BRANCH=${GIT_TEST_BRANCH:-feature/zelta-test}

# remote test host is the machine we'll setup for remote testing
# when a target server is specified, it should be the REMOTE_TEST_HOST

# TODO: consider eliminating REMOTE_TEST_HOST, it looks redundant, consider TGT_SVR, updated dependencies, review, test

export REMOTE_TEST_HOST=${REMOTE_TEST_HOST:-fzfsdev}

# Zelta supports remote commands, by default SRC and TGT servers are the current host
export SRC_SVR="${SRC_SVR:-}"
export TGT_SVR="${TGT_SVR:-}"


if [ -z "$SRC_SVR" ]; then
    export ZELTA_SRC_POOL="${SRC_POOL}"
else
    export ZELTA_SRC_POOL="${SRC_SVR}:${SRC_POOL}"
fi

if [ -z "$TGT_SVR" ]; then
    export ZELTA_TGT_POOL="${TGT_POOL}"
else
    export ZELTA_TGT_POOL="${TGT_SVR}:${TGT_POOL}"
fi

ALL_TESTS_SETUP_DIR=${CUR_DIR}/spec/bin/all_tests_setup

export LOCAL_TMP="${CUR_DIR}/spec/tmp"
export TEST_INSTALL="${LOCAL_TMP}/test_install"
export ZELTA_BIN="$TEST_INSTALL/bin"
export ZELTA_SHARE="$TEST_INSTALL/share/zelta"
export ZELTA_ETC="$TEST_INSTALL/zelta"
export ZELTA_MAN8="$TEST_INSTALL/share/man/man8"

# TODO: remove device support completely or clean it up, currently using image files for pools
# TODO: if keeping it, clean up the tested code for this and support the POOL_TYPE FLAG that selects it
# Default devices if not set
: ${SRC_POOL_DEVICES:="/dev/nvme1n1"}
: ${TGT_POOL_DEVICES:="/dev/nvme2n1"}

export SRC_POOL_DEVICES
export TGT_POOL_DEVICES

export ZFS_MOUNT_BASE="${LOCAL_TMP}/zfs-test-mounts"
export ZELTA_ZFS_STORE_TEST_DIR="${LOCAL_TMP}/zelta-zfs-store-test"
export ZELTA_ZFS_TEST_POOL_SIZE="20G"


# set default pool type
export POOL_TYPE=$FILE_IMG_POOL

setup_os_specific_env
#echo "Using POOL_TYPE: {$POOL_TYPE}"

check_zfs_installed

# If you need to modify the version of awk used
#export ZELTA_AWK=mawk

export PATH="${ZELTA_BIN}:$PATH"

# make exec_cmd silent
# export EXEC_CMD_QUIET=1

