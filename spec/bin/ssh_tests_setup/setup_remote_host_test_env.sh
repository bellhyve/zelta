#!/bin/sh

. spec/bin/all_tests_setup/common_test_env.sh

# pull down zelta from github
ssh ${BACKUP_USER}@${REMOTE_TEST_HOST} << EOF
set -x
rm -fr ${ZELTA_GIT_CLONE_DIR}
mkdir -p ${ZELTA_GIT_CLONE_DIR}
chmod 777 ${ZELTA_GIT_CLONE_DIR}
git clone https://github.com/bellhyve/zelta.git ${ZELTA_GIT_CLONE_DIR}
cd ${ZELTA_GIT_CLONE_DIR}
git checkout $GIT_TEST_BRANCH
ls
set +x
EOF

# scripts
#onetime_setup=${ZELTA_GIT_CLONE_DIR}/test/one_time_test_env_setup.sh
onetime_setup=${ZELTA_GIT_CLONE_DIR}/spec/bin/one_time_setup/setup_sudoers.sh
setup_pools=${ZELTA_GIT_CLONE_DIR}/spec/bin/ssh_tests_setup/setup_zfs_pools_on_remote.sh

# update sudo
ssh -t ${BACKUP_USER}@${REMOTE_TEST_HOST} sudo "${onetime_setup}"

# create pools
ssh -t ${BACKUP_USER}@${REMOTE_TEST_HOST} sudo "${setup_pools}"



