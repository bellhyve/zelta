#!/bin/sh

TEST_BRANCH=feature/zelta-test
#pool_name="tank"
ssh dever@fzfsdev << EOF
set -x
rm -fr /tmp/zelta-dev
mkdir -p /tmp/zelta-dev
git clone https://github.com/bellhyve/zelta.git /tmp/zelta-dev
cd /tmp/zelta-dev
git checkout $TEST_BRANCH
ls
spec/bin/ssh_tests_setup/setup_remote_pools.sh
set +x
EOF

