# shellcheck shell=sh

GREEN=$(printf '\033[32m')
RED=$(printf '\033[31m')
NC=$(printf '\033[0m')

#printf "%sThis is red%s\n" "$RED" "$NC"

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

setup_zfs_allow() {
    SRC_ZFS_CMDS="send,snapshot,hold,bookmark,create,readonly,receive,volmode"
    TGT_ZFS_CMDS="send,snapshot,hold,bookmark,create,readonly,receive,volmode,mount,mountpoint,canmount"
    #TGT_ZFS_CMDS="receive,create,mount,mountpoint,canmount"
    exec_cmd sudo zfs allow -u "$BACKUP_USER" "$SRC_ZFS_CMDS" "$SRC_POOL"
    exec_cmd sudo zfs allow -u "$BACKUP_USER" "$TGT_ZFS_CMDS" "$TGT_POOL"
}
