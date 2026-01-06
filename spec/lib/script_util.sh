. spec/bin/all_tests_setup/env_constants.sh

validate_target() {
    if [ $# -ne 1 ]; then
        echo "Error: validate_target requires exactly 1 argument" >&2
        return 1
    fi

    case "$1" in
        "$RUN_LOCALLY"|"$RUN_REMOTELY")
            export RUNNING_MODE="$1"
            ;;
        *)
            echo "Error: Invalid target '$1'" >&2
            echo "Must be one of: ${RUN_LOCALLY}, ${RUN_REMOTELY}" >&2
            return 1
            ;;
    esac
}


validate_tree_name() {
    if [ $# -ne 1 ]; then
        echo "Error: Expected exactly 1 argument, got $#" >&2
        echo "Usage: $0 <tree_name>" >&2
        echo "  tree_name must be one of: ${STANDARD_TREE}, ${DIVERGENT_TREE}, ${ENCRYPTED_TREE}"
        return 1
    fi

    case "$1" in
        "$STANDARD_TREE"|"$DIVERGENT_TREE"|"$ENCRYPTED_TREE")
            export TREE_NAME=$1
            # Valid value
            ;;
        *)
            echo "Error: Invalid tree_name '$1'" >&2
            echo "Must be one of: ${STANDARD_TREE}, ${DIVERGENT_TREE}, ${ENCRYPTED_TREE}"
            return 1
            ;;
    esac
}
