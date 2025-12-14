


# simple test showing helping function inclusion, logging and output matching

Describe 'hello shellspec'
  Include spec/lib/hello.sh
  setup() {
    %logger "-- BeforeAll setup"
    %logger "-- creating test pools"
    "${INITIALIZE_DIR}"/create_file_backed_zfs_test_pools.sh 2>/dev/null
    CREATE_STATUS=$?

    %logger "-- installing zelta"
    "${INITIALIZE_DIR}"/install_local_zelta.sh
    INSTALL_STATUS=$?

    %logger "-- setting up snap tree"
    "${INITIALIZE_DIR}"/setup_simple_snap_tree.sh
    TREE_STATUS=$?

    %logger "-- Create pool status:    {$CREATE_STATUS}"
    %logger "-- Install Zelta status:  {$INSTALL_STATUS}"
    %logger "-- Make snap tree status: {$TREE_STATUS}"

    SETUP_STATUS=$((CREATE_STATUS || INSTALL_STATUS || TREE_STATUS))
    %logger "-- returning SETUP_STATUS:{$SETUP_STATUS}"
    return $SETUP_STATUS
  }

  cleanup() {
    %logger "-- hello spec cleanup "
  }

  BeforeAll 'setup'
  AfterAll 'cleanup'
  It 'says hello'
    When call hello ShellSpec
    %logger "Your temp dir is {$SHELLSPEC_TMPBASE}"
    The output should match pattern "What's up? Hello ShellSpec! TMPDIR: *"
  End
End