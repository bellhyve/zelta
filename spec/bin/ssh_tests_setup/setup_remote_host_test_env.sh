#!/bin/sh

TEST_BRANCH=feature/zelta-test
TEST_USER=dever
REMOTE_HOST=fzfsdev
#pool_name="tank"
ssh ${TEST_USER}@${REMOTE_HOST} << EOF
set -x
rm -fr /tmp/zelta-dev
mkdir -p /tmp/zelta-dev
git clone https://github.com/bellhyve/zelta.git /tmp/zelta-dev
cd /tmp/zelta-dev
git checkout $TEST_BRANCH
ls
spec/bin/ssh_tests_setup/setup_zfs_pools_on_remote.sh
set +x
EOF

