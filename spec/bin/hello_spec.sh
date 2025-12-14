


# simple test showing helping function inclusion, logging and output matching

Describe 'hello shellspec'
  Include spec/lib/hello.sh
  setup() {
    %logger "--hello spec setup"
    spec/initialize/initialize_testing_setup.sh
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