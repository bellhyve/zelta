#!/bin/sh

. spec/bin/all_tests_setup/common_test_env.sh

echo "Setting sudo for backup user {$BACKUP_USER}"
echo "For zelta-dev root {$ZELTA_DEV_PATH}"

# Detect OS and set paths
if [ -f /etc/os-release ]; then
    . /etc/os-release
    os_name="$ID"
else
    os_name=$(uname -s | tr '[:upper:]' '[:lower:]')
fi

# Set ZFS/zpool paths based on OS
case "$os_name" in
    ubuntu|debian|linux)
        zfs_path="/usr/sbin/zfs"
        zpool_path="/usr/sbin/zpool"
        mount_path="/usr/bin/mount"
        mkdir_path="/usr/bin/mkdir"
        ;;
    freebsd)
        zfs_path="/sbin/zfs"
        zpool_path="/sbin/zpool"
        mount_path="/sbin/mount"
        mkdir_path="/bin/mkdir"
        ;;
    *)
        echo "Unsupported OS: $os_name" >&2
        exit 1
        ;;
esac

# Sudoers entry
setup_script="${ZELTA_DEV_PATH}/spec/bin/ssh_tests_setup/setup_zfs_pools_on_remote.sh"
sudoers_entry="${BACKUP_USER} ALL=(ALL) NOPASSWD: ${zpool_path}, ${zfs_path}, ${mount_path}, ${mkdir_path}, ${setup_script}"

# Sudoers file location
sudoers_file="/etc/sudoers.d/zelta-${BACKUP_USER}"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Check if user exists
if ! id "$BACKUP_USER" >/dev/null 2>&1; then
    echo "User '$BACKUP_USER' does not exist" >&2
    exit 1
fi

# Create sudoers entry
cat > "$sudoers_file" << EOF
# Allow $BACKUP_USER to run ZFS commands without password for zelta testing
# NOTE: This is for test environments only - DO NOT use in production
$sudoers_entry
EOF

# Set correct permissions
chmod 0440 "$sudoers_file"

# Validate the sudoers file
if visudo -c -f "$sudoers_file" >/dev/null 2>&1; then
    echo "Successfully created sudoers entry at: $sudoers_file"
    echo "Entry: $sudoers_entry"
else
    echo "ERROR: Invalid sudoers syntax, removing file" >&2
    rm -f "$sudoers_file"
    exit 1
fi
