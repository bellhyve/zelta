#!/bin/sh



# setting up test pools requires sudo

#echo "hello from initialize"
#echo "INITIALIZE_DIR: {$INITIALIZE_DIR}"
#. spec/initialize/create_file_backed_zfs_test_pools.sh
#set -x
#zfs --help
. ${INITIALIZE_DIR}/create_file_backed_zfs_test_pools.sh
#set +x
#true
# install zelta in a tmp directory locally for testing
#. ${INITIALIZE_DIR}/install_local_zelta.sh
#. ./install.sh

# create a simple test tree of zfs data sets for testing
#. ${INITIALIZE_DIR}/setup_simple_snap_tree.sh
