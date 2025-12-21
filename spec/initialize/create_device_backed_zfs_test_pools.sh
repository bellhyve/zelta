#!/bin/bash

. spec/lib/exec_cmd.sh

# Exit on any error
#set -e

## Configuration via environment variables
## Default pool names if not set
#: ${SRC_POOL:="apool"}
#: ${TGT_POOL:="bpool"}
#
## Default devices if not set
#: ${SRC_POOL_DEVICES:="/dev/nvme1n1"}
#: ${TGT_POOL_DEVICES:="/dev/nvme2n1"}

setup_zfs_allow() {
    SRC_ZFS_CMDS="send,snapshot,hold,bookmark,create,readonly,receive,volmode"
    TGT_ZFS_CMDS="send,snapshot,hold,bookmark,create,readonly,receive,volmode"
    exec_cmd sudo zfs allow -u "$BACKUP_USER" "$SRC_ZFS_CMDS" "$SRC_POOL"
    exec_cmd sudo zfs allow -u "$BACKUP_USER" "$TGT_ZFS_CMDS" "$TGT_POOL"
}


echo "=== ZFS Pool Testing Script ==="
echo "Configuration:"
echo "  SRC_POOL: $SRC_POOL"
echo "  SRC_POOL_DEVICES: $SRC_POOL_DEVICES"
echo "  TGT_POOL: $TGT_POOL"
echo "  TGT_POOL_DEVICES: $TGT_POOL_DEVICES"
echo ""

# Function to check if pool exists
pool_exists() {
    zpool list "$1" &>/dev/null
}

# Function to validate devices exist
validate_devices() {
    local devices="$1"
    local pool_name="$2"

    for dev in $devices; do
        # Skip vdev keywords like 'mirror', 'raidz', etc.
        if [[ "$dev" =~ ^(mirror|raidz|raidz1|raidz2|raidz3|draid|spare|cache|log)$ ]]; then
            continue
        fi

        if [ ! -b "$dev" ]; then
            echo "ERROR: Device $dev for $pool_name does not exist or is not a block device"
            return 1
        fi
    done
}

# Validate all devices exist
echo "Validating devices..."
validate_devices "$SRC_POOL_DEVICES" "$SRC_POOL"
validate_devices "$TGT_POOL_DEVICES" "$TGT_POOL"
echo "  All devices validated"
echo ""

# Clean up any existing pools
echo "Cleaning up existing pools..."
if pool_exists "$SRC_POOL"; then
    exec_cmd sudo zpool destroy "$SRC_POOL"
    echo "  Destroyed existing $SRC_POOL"
fi

if pool_exists "$TGT_POOL"; then
    exec_cmd sudo zpool destroy "$TGT_POOL"
    echo "  Destroyed existing $TGT_POOL"
fi
echo ""

# Create pools
echo "Creating pools..."
exec_cmd sudo zpool create -f "$SRC_POOL" "$SRC_POOL_DEVICES"
echo "  Created $SRC_POOL with devices: $SRC_POOL_DEVICES"

exec_cmd sudo zpool create -f "$TGT_POOL" "$TGT_POOL_DEVICES"
echo "  Created $TGT_POOL with devices: $TGT_POOL_DEVICES"
echo ""

# Verify pools
echo "Verifying pools..."
zpool list "$SRC_POOL" "$TGT_POOL"
echo ""
zpool status "$SRC_POOL"
echo ""
zpool status "$TGT_POOL"
echo ""

setup_zfs_allow

echo "=== Pool creation complete ==="

# Uncomment to test removal and recreation:
# echo "Testing pool removal..."
# sudo zpool destroy "$SRC_POOL"
# sudo zpool destroy "$TGT_POOL"
# echo "  Pools destroyed"
# echo ""

# echo "Recreating pools..."
# sudo zpool create -f "$SRC_POOL" $SRC_POOL_DEVICES
# sudo zpool create -f "$TGT_POOL" $TGT_POOL_DEVICES
# echo "  Pools recreated"
