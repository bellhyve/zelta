#!/bin/sh

# we want to ensure we a running locally
unset SRC_SVR
unset TGT_SVR

echo "Step 1/3: Initializing test environment..."
spec/bin/all_tests_setup/all_tests_setup.sh

echo "Step 2/3: Creating test dataset tree..."
spec/bin/divergent_test/divergent_snap_tree.sh

shellspec $SHELLSPEC_TESTOPT -f d spec/bin/divergent_test/divergent_test_spec.sh:@1
