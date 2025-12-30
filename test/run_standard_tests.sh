#!/usr/bin/env sh
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
sudo spec/initialize/initialize_testing_setup.sh

echo "Step 2/3: Creating test dataset tree..."
sudo spec/initialize/setup_simple_snap_tree.sh

echo "Step 3/3: Running zelta tests..."
#shellspec spec/bin/zelta_standard_test_spec.sh
shellspec -f d spec/bin/zelta_standard_test_spec.sh:@1
shellspec -f d spec/bin/zelta_standard_test_spec.sh:@2

echo ""
echo "✓ Tests complete"