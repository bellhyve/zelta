Describe 'confirm zfs setup'
  #Include spec/lib/hello.sh
  It 'lsblks'
    When call lsblk
    The output should not be empty file
  End
End