# shellcheck shell=sh

# Defining variables and functions here will affect all specfiles.
# Change shell options inside a function may cause different behavior,
# so it is better to set them here.
# set -eu

# This callback function will be invoked only once before loading specfiles.
spec_helper_precheck() {
  # Available functions: info, warn, error, abort, setenv, unsetenv
  # Available variables: VERSION, SHELL_TYPE, SHELL_VERSION
  : minimum_version "0.28.1"
  info "specshell precheck: version:$VERSION shell: $SHELL_TYPE $SHELL_VERSION"
}

# This callback function will be invoked after a specfile has been loaded.
spec_helper_loaded() {
  :
  #set
  echo "spec_helper.sh loaded from $SHELLSPEC_HELPERDIR"
}

start_spec() {
  :
  #echo ${This.name}
  #echo "staring spec"
  echo "starting {$SHELLSPEC_SPECFILE}"
}

end_spec() {
  :
  #echo "ending spec"
  echo "ending {$SHELLSPEC_SPECFILE}"
}

start_all() {
  :
  #ls -l "./spec/lib/create_file_backed_zfs_test_pools.sh"
  #. "./spec/lib/create_file_backed_zfs_test_pools.sh"
  curdir=$(pwd)
  echo "spec_helper.sh start_all curdir:$curdir"
  #./spec/initialize/create_file_backed_zfs_test_pools.sh

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


# In spec_helper.sh
capture_stderr() {
  RESULT=$({ "$@" 2>&1 1>/dev/null; } 2>&1) || true
  #RESULT="hello"
}


#spec/initialize/test_env.sh

