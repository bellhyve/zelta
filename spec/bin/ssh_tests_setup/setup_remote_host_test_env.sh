#!/bin/sh

. spec/bin/all_tests_setup/common_test_env.sh
. spec/lib/script_util.sh

if ! validate_tree_name "$@"; then
    return 1
fi

echo "TREE_NAME is {$TREE_NAME}"

# Use a string for the following remote setup so sudo password only has to be entered once.
# pull down zelta from github into a clean dir
# checkout the test branch
# update sudoers
# setup the test env, install zelta, create pools
# create the requested snap tree


printf "\n*** Enter sudo password for remote setup:\n"
ssh -t ${BACKUP_USER}@${REMOTE_TEST_HOST} "
    set -e &&
    set -x &&

    sudo rm -fr ${ZELTA_GIT_CLONE_DIR} &&

    mkdir -p ${ZELTA_GIT_CLONE_DIR} &&
    chmod 777 ${ZELTA_GIT_CLONE_DIR} &&
    git clone https://github.com/bellhyve/zelta.git ${ZELTA_GIT_CLONE_DIR} &&
    cd ${ZELTA_GIT_CLONE_DIR} &&
    git checkout ${GIT_TEST_BRANCH} &&

    sudo ${ZELTA_GIT_CLONE_DIR}/spec/bin/one_time_setup/setup_sudoers.sh &&
    sudo ${ZELTA_GIT_CLONE_DIR}/spec/bin/all_tests_setup/all_tests_setup.sh &&
    sudo ${ZELTA_GIT_CLONE_DIR}/spec/bin/${TREE_NAME}_test/${TREE_NAME}_snap_tree.sh &&

    echo 'Remote setup complete'
"
