#!/bin/sh

. spec/lib/common.sh

CUR_DIR=$(pwd)

# backup username, should be configured for ssh access on remotes
export BACKUP_USER="${BACKUP_USER:-dever}"
#export BACKUP_USER="${SUDO_USER:-$(whoami)}"

# location for git pulls of source for testing
export ZELTA_GIT_CLONE_DIR="${ZELTA_GIT_CLONE_DIR:-/tmp/zelta-dev}"
export GIT_TEST_BRANCH=feature/zelta-test
export REMOTE_TEST_HOST=fzfsdev
#ZELTA_DEV_PATH=/tmp/zelta-dev


# Zelta supports remote commands, by default SRC and TGT servers are the current host
export SRC_SVR="${SRC_SVR:-}"
export TGT_SVR="${TGT_SVR:-}"
export SRC_POOL="apool"
export TGT_POOL="bpool"
export ZELTA_SRC_POOL="${SRC_SVR}${SRC_POOL}"
export ZELTA_TGT_POOL="${TGT_SVR}${TGT_POOL}"


ALL_TESTS_SETUP_DIR=${CUR_DIR}/spec/bin/all_tests_setup
#export INITIALIZE_DIR="${CUR_DIR}/spec/initialize"
export LOCAL_TMP="${CUR_DIR}/spec/tmp"
#export INITIALIZATION_COMPLETE_MARKER_FILE="$LOCAL_TMP/.initialize_testing_setup_complete"
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

##export SRC_SVR=dever@fzfsdev:
##export TGT_SVR=dever@fzfsdev:



#export TREETOP_DSN='treetop'
#export BACKUPS_DSN='backups'
#export SOURCE=${SRC_SVR}${SRC_POOL}/${TREETOP_DSN}
#export TARGET=${TGT_SVR}${TGT_POOL}/${BACKUPS_DSN}
#export SRC_TREE="$SRC_POOL/$TREETOP_DSN"
#export TGT_TREE="$TGT_POOL/$BACKUPS_DSN/$TREETOP_DSN"
#export ALL_DATASETS="one/two/three"


export ZFS_MOUNT_BASE="${LOCAL_TMP}/zfs-test-mounts"
export ZELTA_ZFS_STORE_TEST_DIR="${LOCAL_TMP}/zelta-zfs-store-test"
export ZELTA_ZFS_TEST_POOL_SIZE="20G"


export FILE_IMG_POOL=1
export LOOP_DEV_POOL=2

# set default pool type
export POOL_TYPE=$FILE_IMG_POOL

setup_os_specific_env
#echo "Using POOL_TYPE: {$POOL_TYPE}"

check_zfs_installed

# If you need to modify the version of awk used
#export ZELTA_AWK=mawk

export PATH="${ZELTA_BIN}:$PATH"

#export EXEC_CMD_QUIET=1

