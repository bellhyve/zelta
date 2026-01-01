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

echo "Step 1/3: Initializing test environment..."
spec/bin/all_tests_setup/all_tests_setup.sh

echo "Step 2/3: Creating test dataset tree..."
spec/bin/standard_test/standard_snap_tree.sh
