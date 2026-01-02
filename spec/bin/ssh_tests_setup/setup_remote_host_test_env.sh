#!/bin/sh

TEST_BRANCH=feature/zelta-test
TEST_USER=dever
REMOTE_HOST=fzfsdev
TEST_DIR=/tmp/zelta-dev

ssh ${TEST_USER}@${REMOTE_HOST} << EOF
set -x
rm -fr ${TEST_DIR}
mkdir -p ${TEST_DIR}
chmod 777 ${TEST_DIR}
git clone https://github.com/bellhyve/zelta.git ${TEST_DIR}
cd ${TEST_DIR}
git checkout $TEST_BRANCH
ls
sudo spec/bin/ssh_tests_setup/setup_zfs_pools_on_remote.sh
set +x
EOF

