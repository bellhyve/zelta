Describe 'confirm zfs setup'
    setup() {
        %logger "-- setup zelta test environment"
        spec/initialize/initialize_testing_setup.sh
    }

    create_marker_file() {
        #%logger "-- creating marker file {$INITIALIZATION_COMPLETE_MARKER_FILE}"
        touch "${INITIALIZATION_COMPLETE_MARKER_FILE}"
    }

    #BeforeAll setup
    #AfterAll  create_marker_file

    It "has good initial SRC_POOL:{$SRC_POOL} simple snap tree"
        When call sudo zfs list -r "$SRC_POOL"
        The line 2 of output should match pattern "* /$SRC_POOL"
        The line 3 of output should match pattern "* /$SRC_POOL/$TREETOP_DSN"
        The line 4 of output should match pattern "* /$SRC_POOL/$TREETOP_DSN/one"
        The line 5 of output should match pattern "* /$SRC_POOL/$TREETOP_DSN/one/two"
        The line 6 of output should match pattern "* /$SRC_POOL/$TREETOP_DSN/one/two/three"
     End

     It "has good initial TGT_POOL:{$TGT_POOL} simple snap tree"
         When call sudo zfs list -r "$TGT_POOL"
         The line 2 of output should match pattern "* /$TGT_POOL"
     End
End

Describe 'try backup'
    It 'backs up the initial tree'
        When call zelta backup $SRC_POOL/$TREETOP_DSN $TGT_POOL/$BACKUPS_DSN
        The stderr should match pattern "* cannot open '$TGT_POOL/$BACKUPS_DSN': dataset does not exist"
        The stdout should not be blank
        The status should eq 0
    End

#    It 'has valid backup'
#        When call sudo zfs list -r "$TGT_POOL"
#        The line 2 of output should match pattern "* /$TGT_POOL"
#        The line 3 of output should match pattern "* /$TGT_POOL/$BACKUPS_DSN"
#        The line 4 of output should match pattern "* /$TGT_POOL/$BACKUPS_DSN/one"
#        The line 5 of output should match pattern "* /$TGT_POOL/$BACKUPS_DSN/one/two"
#        The line 6 of output should match pattern "* /$TGT_POOL/$BACKUPS_DSN/one/two/three"
#    End
End
