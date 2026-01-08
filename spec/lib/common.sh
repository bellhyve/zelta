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

snapshot_count() {
    expected_count=$1
    pattern=$2  # Optional regex pattern
    svr=$3 # Optional server name

    # Validate arguments
    if [ -z "$expected_count" ]; then
        echo "Error: snapshot_count requires expected_count argument" >&2
        return 1
    fi

    # Validate expected_count is a number
    case "$expected_count" in
        ''|*[!0-9]*)
            echo "Error: expected_count must be a number" >&2
            return 1
            ;;
    esac

    # Get snapshot list
    snapshot_list=$(exec_on "$svr" zfs list -t snapshot -H -o name)

    # Count snapshots, optionally filtering by pattern
    if [ -n "$pattern" ]; then
        # Count only snapshots matching the pattern
        snapshot_count=$(echo "$snapshot_list" | grep -E "$pattern" | wc -l)
    else
        # Count all snapshots
        snapshot_count=$(echo "$snapshot_list" | wc -l)
    fi

    # Test the count
    if [ "$expected_count" -eq "$snapshot_count" ]; then
        return 0
    else
        if [ -n "$pattern" ]; then
            echo "Expected $expected_count snapshots matching pattern '$pattern', found $snapshot_count" >&2
        else
            echo "Expected $expected_count snapshots, found $snapshot_count" >&2
        fi
        return 1
    fi
}

# Shellspec has a nice tracing feature when you specify --xtrace, but it doesn't execute
# expectations unless you use --shell bash, and the bash shell has to be >= version 4.
# Using --xtrace without --shell is an easy mistake to make and it looks like tests are
# passing when they are not, as no expectations are run. Therefore, we use this function
# to check if --xtrace has been specifie
# d, we assert that --shell bash is also present.
# see https://deepwiki.com/shellspec/shellspec/5.1-command-line-options#tracing-and-profiling
#check_if_xtrace_expectations_supported() {
check_if_xtrace_usage_valid() {
    # use --shell bash --xtrace to see trace of execution and evaluates expectations
    # bash version must be >= 4

    # Return error if SHELLSPEC_XTRACE is defined, SHELLSPEC_SHELL contains bash,
    # and bash version is less than 4
    if [ -n "$SHELLSPEC_XTRACE" ]; then
        #echo "*** checking SHELLSPEC_SHELL: {$SHELLSPEC_SHELL}"
        if echo "$SHELLSPEC_SHELL" | grep -q bash; then
            #echo "*** found bash: {$SHELLSPEC_SHELL}"
            if [ -n "$BASH_VERSION" ]; then
                # Extract major version (first element of BASH_VERSINFO)
                if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
                    echo "Error: xtrace with bash requires version 4 or higher (current: $BASH_VERSION)" >&2
                    return 1
                fi
            else
                # SHELLSPEC_SHELL contains bash but we're not running in bash
                # Try to check the version of the specified bash
                bash_version=$("$SHELLSPEC_SHELL" --version 2>/dev/null | head -n1)
                if echo "$bash_version" | grep -q "version [0-3]\."; then
                    echo "Error: xtrace with bash requires version 4 or higher (detected: $bash_version)" >&2
                    return 1
                fi
            fi
        else
            echo "Error: --xtrace requires bash shell, please add the option --shell bash" >&2
            return 1
        fi
    fi
}

setup_linux_zfs_allow() {
    export SRC_ZFS_CMDS="send,snapshot,hold,bookmark,create,readonly,receive,volmode,mount,mountpoint,canmount,rename"
    export TGT_ZFS_CMDS="send,snapshot,hold,bookmark,create,readonly,receive,volmode,mount,mountpoint,canmount,rename"
}

setup_freebsd_zfs_allow() {
    export SRC_ZFS_CMDS="send,snapshot,hold,bookmark,create,readonly,receive,volmode,mount,mountpoint,canmount,rename"
    export TGT_ZFS_CMDS="send,snapshot,hold,bookmark,create,readonly,receive,volmode,mount,mountpoint,canmount,rename"
}

setup_linux_env() {
    setup_linux_zfs_allow
    export POOL_TYPE="$LOOP_DEV_POOL"
    export ZELTA_AWK=mawk
}

setup_freebsd_env() {
    setup_freebsd_zfs_allow
    export POOL_TYPE="$MEMORY_DISK_POOL"
}

setup_zfs_allow() {
    exec_cmd sudo zfs allow -u "$BACKUP_USER" "$SRC_ZFS_CMDS" "$SRC_POOL"
    exec_cmd sudo zfs allow -u "$BACKUP_USER" "$TGT_ZFS_CMDS" "$TGT_POOL"
}

setup_os_specific_env() {
    # uname is the most reliable cross‑platform starting point
    OS_TYPE=$(uname -s)
    echo "Settings OS specific environment for {$OS_TYPE}"

    # Check for Ubuntu specifically
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$ID" = "ubuntu" ]; then
            # NOTE: This isn't being used currently
            export LINUX_DISTRO_IS_UBUNTU=1
        fi
    fi

    case "$OS_TYPE" in
        Linux)
            # Linux distros
            setup_linux_env
            ;;
        FreeBSD|Darwin)
            setup_freebsd_env
            ;;
        *)
            echo "$OS_TYPE: Unsupported OS_TYPE: {$OS_TYPE}" >&2
            return 1
            ;;
    esac

    echo "OS_TYPE: $OS_TYPE: set POOL_TYPE={$POOL_TYPE}"
}



setup_zelta_env() {
    :;
}