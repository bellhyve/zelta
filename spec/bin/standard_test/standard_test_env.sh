#!/bin/sh

. spec/bin/all_tests_setup/common_test_env.sh
. spec/lib/common.sh

export TREETOP_DSN='treetop'
export BACKUPS_DSN='backups'

# zelta version for pool names will include the remote
export SOURCE="${ZELTA_SRC_POOL}/${TREETOP_DSN}"
export TARGET="${ZELTA_TGT_POOL}/${BACKUPS_DSN}/${TREETOP_DSN}"

# zfs versions for pool names do not include th eremote
export SRC_TREE="$SRC_POOL/$TREETOP_DSN"
export TGT_TREE="$TGT_POOL/$BACKUPS_DSN/$TREETOP_DSN"

export ALL_DATASETS="one/two/three"
