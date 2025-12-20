# shellcheck shell=sh

old_exec_cmd() {
    #printf '%s' "$*" >&2
    printf '%s' "$*"
    if "$@"; then
        #printf ' :* succeeded\n' >&2
        printf ' :* succeeded\n'
        return 0
    else
        _exit_code=$?
        #printf ' :! failed (exit code: %d)\n' "$_exit_code" >&2
        printf ' :! failed (exit code: %d)\n' "$_exit_code"
        return "$_exit_code"
    fi
}

exec_cmd() {
    if [ "${EXEC_CMD_QUIET:-}" != "1" ]; then
        printf '%s' "[exec] $*"
    fi
    if "$@"; then
        [ "${EXEC_CMD_QUIET:-}" != "1" ] && printf ' :* succeeded\n'
        return 0
    else
        _exit_code=$?
        [ "${EXEC_CMD_QUIET:-}" != "1" ] && printf ' :! failed (exit code: %d)\n' "$_exit_code"
        return "$_exit_code"
    fi
}