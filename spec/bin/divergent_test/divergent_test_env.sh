#!/bin/sh

. spec/bin/all_tests_setup/common_test_env.sh
. spec/lib/common.sh

SRCTOP='apool'
TGTTOP='bpool'
SRCTREE="$SRCTOP/treetop"
TGTTREE="$TGTTOP/backups/treetop"
