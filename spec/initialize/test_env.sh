#!/bin/sh

. spec/lib/common.sh

CUR_DIR=$(pwd)

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

##export SRC_SVR=dever@fzfsdev:
##export TGT_SVR=dever@fzfsdev:
SRC_SVR=
TGT_SVR=
export SRC_POOL='apool'
export TGT_POOL='bpool'
export TREETOP_DSN='treetop'
export BACKUPS_DSN='backups'
export SOURCE=${SRC_SVR}${SRC_POOL}/${TREETOP_DSN}
export TARGET=${TGT_SVR}${TGT_POOL}/${BACKUPS_DSN}
export SRC_TREE="$SRC_POOL/$TREETOP_DSN"
export TGT_TREE="$TGT_POOL/$BACKUPS_DSN/$TREETOP_DSN"
export ALL_DATASETS="one/two/three"


export ZFS_MOUNT_BASE="${LOCAL_TMP}/zfs-test-mounts"
export ZELTA_ZFS_STORE_TEST_DIR="${LOCAL_TMP}/zelta-zfs-store-test"
export ZELTA_ZFS_TEST_POOL_SIZE="20G"


export FILE_IMG_POOL=1
export LOOP_DEV_POOL=2

# set default pool type
export POOL_TYPE=$FILE_IMG_POOL

setup_os_specific_env
#echo "Using POOL_TYPE: {$POOL_TYPE}"

export BACKUP_USER="${SUDO_USER:-$(whoami)}"

check_zfs_installed

# If you need to modify the version of awk used
#export ZELTA_AWK=mawk

export PATH="${ZELTA_BIN}:$PATH"

#export EXEC_CMD_QUIET=1
