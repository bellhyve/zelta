Describe 'confirm zfs setup'
    setup() {
        %logger "-- setup zelta test environment"
        spec/initialize/initialize_testing_setup.sh
    }

    BeforeAll setup

    It "has good initial SRC_POOL:{$SRC_POOL} simple snap tree"
        When call zfs list -r "$SRC_POOL"
        The line 2 of output should match pattern "* /$SRC_POOL"
        The line 3 of output should match pattern "* /$SRC_POOL/treetop"
        The line 4 of output should match pattern "* /$SRC_POOL/treetop/one"
        The line 5 of output should match pattern "* /$SRC_POOL/treetop/one/two"
        The line 6 of output should match pattern "* /$SRC_POOL/treetop/one/two/three"
     End

     It "has good initial TGT_POOL:{$TGT_POOL} simple snap tree"
         When call zfs list -r "$TGT_POOL"
         The line 2 of output should match pattern "* /$TGT_POOL"
     End

End
