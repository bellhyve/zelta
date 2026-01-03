#!/bin/sh
set -e

cat <<EOF
=== Zelta Test Suite ===

This test suite requires temporary root access for:
  • Creating ZFS test datasets (Linux mount restrictions)
  • Setting up test pools with proper permissions

The actual backup tests run with normal user privileges via ZFS delegation.
You'll be prompted for your password for the setup steps.

EOF

# we want to ensure we a running locally
unset SRC_SVR
unset TGT_SVR

echo "Step 1/3: Initializing test environment..."
spec/bin/all_tests_setup/all_tests_setup.sh

echo "Step 2/3: Creating test dataset tree..."
spec/bin/standard_test/standard_snap_tree.sh

echo "Step 3/3: Running zelta tests..."

OPTIONS="${OPTIONS:-}"
#shellspec spec/bin/standard_test/standard_test_spec.sh
shellspec -f d $OPTIONS spec/bin/standard_test/standard_test_spec.sh:@1
shellspec -f d $OPTIONS spec/bin/standard_test/standard_test_spec.sh:@2
shellspec -f d $OPTIONS spec/bin/standard_test/standard_test_spec.sh:@3

echo ""
echo "✓ Tests complete"