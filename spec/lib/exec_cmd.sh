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


#printf "\033[31mThis is red text\033[0m\n"
#printf "\033[32mThis is green text\033[0m\n"
#printf "\033[34mThis is blue text\033[0m\n"


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



    #if [ "${EXEC_CMD_QUIET:-}" != "1" ]; then
    #   
    #	printf '\033[33m[exec]\033[0m %s\n' "$CMD"
    #fi
