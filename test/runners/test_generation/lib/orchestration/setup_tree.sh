# helper to setup the test zfs pools and datasets in the
# state needed for creating/generating a new test and
# for testing the same.

REPO_ROOT=${REPO_ROOT:=$(git rev-parse --show-toplevel)}
echo "REPO ROOT: $REPO_ROOT"

initialize_setup_tree_env() {
    if [ ! -d "$REPO_ROOT" ]; then
        echo "repo root $REPO_ROOT not found" >&2
        return 1
    fi
    cd "$REPO_ROOT"

    if ! . ./test/test_helper.sh; then
        echo "source ./test/test_helper.sh failed"
        return 1
    fi

    if ! . ./test/runners/env/helpers.sh; then
        echo "source ./test/runners/env/helpers.sh failed"
        return 1
    fi

    if ! setup_env "1"; then
        echo "setup_env failed"
        return 1
    fi

    if ! clean_ds_and_pools; then
        echo "clean_ds_and_pools failed"
        return 1
    fi

    return 0
}

setup_tree() {
    echo "calling initialize"
    if ! initialize_setup_tree_env; then
        printf '\n ❌ failed to initialize environment for setup_env\n' >&2
        return 1
    fi

    export SANDBOX_ZELTA_TMP_SUFFIX=$LOGNAME

    options=""
    for arg in "$@"; do
        case $arg in
            options=*) options=${arg#*=} ;;
        esac
    done

    count=0
    for arg in "$@"; do
        value=${arg#*=}
        echo "processing arg:{$arg} with value:{$value}"
        case $arg in
            # shellcheck disable=SC2086  # $options intentionally word-split
            pattern=*) set -- shellspec $options --pattern "$value" ;;
            tag=*)     set -- shellspec $options --tag "$value"     ;;
            path=*)    set -- shellspec $options "$value"           ;;
            options=*) continue ;;
            *) printf 'unknown arg: %s\n' "$arg" >&2; return 2 ;;
        esac

        count=$((count + 1))
        printf '▶ [%d] %s\n' "$count" "$*"      # echo the exact argv

        status=0
        "$@" || status=$?                        # run that same argv
        if [ "$status" -ne 0 ]; then
            printf '\n ❌ failed (#%d): %s\n' "$count" "$*" >&2
            return 1
        fi
    done

    printf "\n ✅ setup succeeded — ran %d command(s)\n" "$count"
}
