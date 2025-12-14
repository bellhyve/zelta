#!/bin/sh

#set -x

CUR_DIR=$(pwd)
#echo "$CUR_DIR"

export INITIALIZE_DIR="${CUR_DIR}/spec/initialize"

export LOCAL_TMP="${CUR_DIR}/spec/tmp"
export TEST_INSTALL="${LOCAL_TMP}/test_install"
export ZFS_BIN="/usr/local/sbin"
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

export PATH="${ZELTA_BIN}":${ZFS_BIN}:/usr/bin:/bin

#set +x
#true

