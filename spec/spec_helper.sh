# shellcheck shell=sh

#. spec/initialize/test_env.sh
# Defining variables and functions here will affect all specfiles.
# Change shell options inside a function may cause different behavior,
# so it is better to set them here.
# set -eu


#case_insensitive_equals() {
#    $str=$1
#    $str=$2
#    if [ "$(echo "$str1" | tr '[:upper:]' '[:lower:]')" = "$(echo "$str2" | tr '[:upper:]' '[:lower:]')" ]; then
#        return 0
#    fi
#    return 1
#}

# This callback function will be invoked only once before loading specfiles.
spec_helper_precheck() {
    # Available functions: info, warn, error, abort, setenv, unsetenv
    # Available variables: VERSION, SHELL_TYPE, SHELL_VERSION
    : minimum_version "0.28.1"
    info "specshell precheck: version:$VERSION shell: $SHELL_TYPE $SHELL_VERSION"
    info "*** TREE_NAME    is {$TREE_NAME}"
    info "*** RUNNING_MODE is {$RUNNING_MODE}"
    if [ "$RUNNING_MODE" = "$RUN_REMOTELY" ]; then
        info "***"
        info "*** Running Remotely"
        info "*** Source Server is SRC_SVR:{$SRC_SVR}"
        info "*** Target Server is TGT_SVR:{$TGT_SVR}"
        info "***"
    else
        info "***"
        info "*** Running Locally"
        info "***"
    fi

    # Convert both to lowercase for comparison
    #if case_insensitive_equals $RUNNING_MODE "remote"
}

# This callback function will be invoked after a specfile has been loaded.
spec_helper_loaded() {
    :
    #echo "spec_helper.sh loaded from $SHELLSPEC_HELPERDIR"
}

start_spec() {
    :
    # echo "starting {$SHELLSPEC_SPECFILE}"
}

end_spec() {
    :
    # echo "ending {$SHELLSPEC_SPECFILE}"
}

start_all() {
    :
    #exec_cmd "echo 'hello there'"
    #ls -l "./spec/lib/create_file_backed_zfs_test_pools.sh"
    #. "./spec/lib/create_file_backed_zfs_test_pools.sh"
    #curdir=$(pwd)
    #echo "spec_helper.sh start_all curdir:$curdir"
    #./spec/initialize/create_file_backed_zfs_test_pools.sh
    #./spec/initialize/initialize_testing_setup.sh

    #echo "staring all"
    #. ./spec/initialize/initialize_testing_setup
}

end_all() {
    :
    #echo "after all"
}

# This callback function will be invoked after core modules has been loaded.
spec_helper_configure() {
    # Available functions: import, before_each, after_each, before_all, after_all
    : import 'support/custom_matcher'
    before_each start_spec
    after_each end_spec
    before_all start_all
    after_all end_all
}

# Define helper functions AFTER spec_helper_configure
# These will be available in all spec files and in before_all/after_all blocks
exec_cmd() {
    printf '%s' "$*" >&2
    if "$@"; then
        printf ' :* succeeded\n' >&2
        return 0
    else
        _exit_code=$?
        printf ' :! failed (exit code: %d)\n' "$_exit_code" >&2
        return "$_exit_code"
    fi
}


# In spec_helper.sh
capture_stderr() {
    RESULT=$({ "$@" 2>&1 1>/dev/null; } 2>&1) || true
    #RESULT="hello"
}

#spec/initialize/test_env.sh

#exec_cmd printf "hello there\n"
