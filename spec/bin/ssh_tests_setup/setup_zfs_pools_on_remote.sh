#!/bin/sh
set -e

# This scripts runs as ssh on the designated remote host
# and there is no environment set. We make the current directory
# the location of the git clone for zelta
cd_to_git_clone_dir() {
    script_dir=$(cd "$(dirname "$0")" && pwd)
    parent_dir=$(dirname "$script_dir")
    cd "$parent_dir/../.." || exit 1
    cur_dir=$(pwd)
    echo "git zelta clone directory is: {$cur_dir}"
}

cd_to_git_clone_dir

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
