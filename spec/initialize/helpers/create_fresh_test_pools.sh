#!/bin/sh

set -x

# Create a small test file
truncate -s 100M /tmp/test.img
sudo losetup -f /tmp/test.img
LOOP=$(losetup -a | grep test.img | cut -d: -f1)
echo "Loop device: $LOOP"

# Create a simple test pool
sudo zpool create testpool $LOOP
sudo zfs create testpool/test

# Try delegation on this fresh pool
sudo zfs allow dever read testpool/test

set +x
