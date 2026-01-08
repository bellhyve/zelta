#!/bin/sh

set -e

. spec/lib/script_util.sh



test_setup() {
    if [ $# -ne 2 ]; then
        echo "Error: Expected 2 arguments: <target> <tree_name>" >&2
        echo "Usage: $0 <${RUN_LOCALLY}|${RUN_REMOTELY}> <${STANDARD_TREE}|${DIVERGENT_TREE}|${ENCRYPTED_TREE}>" >&2
        return 1
    fi

    if ! validate_target "$1"; then
        return 1
    fi

    if ! validate_tree_name "$2"; then
        return 1
    fi

    case "$RUNNING_MODE" in
        "$RUN_LOCALLY")
            unset TGT_SVR
            unset SRV_SVR
            exec_local_setup
            ;;
        "$RUN_REMOTELY")
            export SRC_SVR="${SRC_SVR:-dever@fzfsdev}"
            # TODO: sort out 2nd server send/receive with host alias fzfsdev2
            # export TGT_SVR="${TGT_SVR:-dever@fzfsdev2}"
            export TGT_SVR="${TGT_SVR:-dever@fzfsdev}"
            exec_remote_setup
            ;;
    esac

}

exec_local_setup() {
    printf "\n***\n*** Running Locally\n***\n"

    echo "Step 1/3: Initializing local test environment..."
    spec/bin/all_tests_setup/all_tests_setup.sh

    echo "Step 2/3: Creating test dataset tree..."
    sudo spec/bin/${TREE_NAME}_test/${TREE_NAME}_snap_tree.sh
}

exec_remote_setup() {
    printf "\n***\n*** Running Remotely: SRC_SVR:{$SRC_SVR} TGT_SVR:{$TGT_SVR}\n***\n"

    echo "Steps 1 and 2, Initializing remote setup, create pools setup snap tree"
    spec/bin/ssh_tests_setup/setup_remote_host_test_env.sh $TREE_NAME
}

run_tests() {
    echo "Step 3/3: Running zelta tests..."

    # shellspec options to include
    #SHELLSPEC_TESTOPT="${SHELLSPEC_TESTOPT:-}"

    # this options will show a trace with expectation evaluation
    #SHELLSPEC_TESTOPT="--xtrace --shell bash"

    unset SHELLSPEC_TESTOPT

    shellspec -f d $SHELLSPEC_TESTOPT spec/bin/${TREE_NAME}_test/${TREE_NAME}_test_spec.sh

    # examples of selective tests runs
    # shellspec -f d $SHELLSPEC_TESTOPT spec/bin/${TREE_NAME}_test/${TREE_NAME}_test_spec.sh:@1
    # shellspec -f d $SHELLSPEC_TESTOPT spec/bin/${TREE_NAME}_test/${TREE_NAME}_test_spec.sh:@2
    # shellspec -f d $SHELLSPEC_TESTOPT spec/bin/${TREE_NAME}_test/${TREE_NAME}_test_spec.sh:@2-1
    # shellspec -f d $SHELLSPEC_TESTOPT spec/bin/${TREE_NAME}_test/${TREE_NAME}_test_spec.sh:@2-2

    echo ""
    echo "✓ Tests complete"
}

if test_setup "$@"; then
    # NOTE: update the environment after SRC_SVR and TGT_SVR are set!!
    . spec/bin/all_tests_setup/common_test_env.sh
    run_tests
    #printf "***\n*** check tree run tests manually\n***\n"
fi
