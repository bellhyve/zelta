# shellcheck shell=sh

GREEN=$(printf '\033[32m')
RED=$(printf '\033[31m')
NC=$(printf '\033[0m')

#printf "%sThis is red%s\n" "$RED" "$NC"

check_zfs_installed() {
    # Check if zfs is already on PATH
    if ! command -v zfs >/dev/null 2>&1; then
        # Allow user to override ZFS_BIN location, default to /usr/local/sbin
        ZFS_BIN="${ZFS_BIN:-/usr/local/sbin}"

        # Add ZFS_BIN to PATH if not already present
        case ":$PATH:" in
        *":$ZFS_BIN:"*) ;;
        *) PATH="$ZFS_BIN:$PATH" ;;
        esac
        export PATH

        # Verify zfs command is now available
        if ! command -v zfs >/dev/null 2>&1; then
            echo "Error: zfs command not found. Please set ZFS_BIN to the correct location." >&2
            return 1
        fi
    fi
}

exec_cmd() {
    CMD=$(printf "%s " "$@")
    CMD=${CMD% }    # trim trailing space
    #CMD="$@"
    if "$@"; then
        [ "${EXEC_CMD_QUIET:-}" != "1" ] && printf "${GREEN}[success] ${CMD}${NC}\n"
        return 0
    else
        _exit_code=$?
        [ "${EXEC_CMD_QUIET:-}" != "1" ] && printf "${RED}[failed] ${CMD}${NC}\n" "$_exit_code"
        return "$_exit_code"
    fi
}

exec_on() {
    local server="$1"
    shift

    if [ -n "$server" ]; then
        ssh "$server" "$@"
    else
        "$@"
    fi
}


setup_linux_zfs_allow() {
    export SRC_ZFS_CMDS="send,snapshot,hold,bookmark,create,readonly,receive,volmode,mount,mountpoint,canmount"
    export TGT_ZFS_CMDS="send,snapshot,hold,bookmark,create,readonly,receive,volmode,mount,mountpoint,canmount"
}

setup_freebsd_zfs_allow() {
    export SRC_ZFS_CMDS="send,snapshot,hold,bookmark,create,readonly,receive,volmode,mount,mountpoint,canmount"
    export TGT_ZFS_CMDS="send,snapshot,hold,bookmark,create,readonly,receive,volmode,mount,mountpoint,canmount"
}


setup_linux_env() {
    setup_linux_zfs_allow
    export POOL_TYPE="$LOOP_DEV_POOL"
}

setup_freebsd_env() {
    setup_freebsd_zfs_allow
    export POOL_TYPE="$FILE_IMG_POOL"
}



setup_zfs_allow() {

#mount
#unmount
#create
#destroy
#snapshot
#send
#receive
#hold/release



    #TGT_ZFS_CMDS="receive,create,mount,mountpoint,canmount"
    exec_cmd sudo zfs allow -u "$BACKUP_USER" "$SRC_ZFS_CMDS" "$SRC_POOL"
    exec_cmd sudo zfs allow -u "$BACKUP_USER" "$TGT_ZFS_CMDS" "$TGT_POOL"
}

setup_os_specific_env() {
    # uname is the most reliable cross‑platform starting point
    OS_TYPE=$(uname -s)
    echo "Settings OS specific environment for {$OS_TYPE}"
    case "$OS_TYPE" in
        Linux)
            # Check for Ubuntu specifically
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                if [ "$ID" = "ubuntu" ]; then
                    echo "$OS_TYPE: setting: POOL_TYPE=\$LOOP_DEV_POOL:$LOOP_DEV_POOL"
                    setup_linux_env
                    return
                fi
            fi
            # fallback for other Linux distros
            echo "$OS_TYPE: setting: POOL_TYPE=\$LOOP_DEV_POOL:$LOOP_DEV_POOL"
            setup_linux_env
            ;;
        FreeBSD|Darwin)
            echo "$OS_TYPE: setting: POOL_TYPE=\$FILE_IMG_POOL:$FILE_IMG_POOL"
            setup_freebsd_env
            ;;
        *)
            echo "$OS_TYPE: Unsupported OS_TYPE: {$OS_TYPE}" >&2
            return 1
            ;;
    esac
}



setup_zelta_env() {
    :;
}