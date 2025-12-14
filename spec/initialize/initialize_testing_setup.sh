#!/bin/sh

pwd

echo "-- BeforeAll setup"

echo "-- installing zelta"
"${INITIALIZE_DIR}"/install_local_zelta.sh
INSTALL_STATUS=$?
if [ $INSTALL_STATUS -ne 0 ]; then
  echo "** Error: zelta install failed"
fi

TREE_STATUS=1

echo "-- creating test pools"
if "${INITIALIZE_DIR}"/create_file_backed_zfs_test_pools.sh; then
   echo "-- setting up snap tree"
   "${INITIALIZE_DIR}"/setup_simple_snap_tree.sh
   TREE_STATUS=$?
else
   echo "** Error: failed to setup zfs pool" >&2
fi

#CREATE_STATUS=$?


#echo "-- Create pool status:    {$CREATE_STATUS}"
echo "-- Install Zelta status:  {$INSTALL_STATUS}"
echo "-- Make snap tree status: {$TREE_STATUS}"

#SETUP_STATUS=$((CREATE_STATUS || INSTALL_STATUS || TREE_STATUS))
SETUP_STATUS=$((INSTALL_STATUS || TREE_STATUS))
echo "-- returning SETUP_STATUS:{$SETUP_STATUS}"

if [ $SETUP_STATUS -ne 0 ]; then
   echo "** Error: zfs pool and/or zelta install failed!" >&2
fi

return $SETUP_STATUS

# setting up test pools requires sudo

#echo "hello from initialize"
#echo "INITIALIZE_DIR: {$INITIALIZE_DIR}"
#. spec/initialize/create_file_backed_zfs_test_pools.sh
#set -x
#zfs --help
#. ${INITIALIZE_DIR}/create_file_backed_zfs_test_pools.sh
#set +x
#true
# install zelta in a tmp directory locally for testing
#. ${INITIALIZE_DIR}/install_local_zelta.sh
#. ./install.sh

# create a simple test tree of zfs data sets for testing
#. ${INITIALIZE_DIR}/setup_simple_snap_tree.sh
