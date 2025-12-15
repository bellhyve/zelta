Describe 'Zelta backup'
    check_marker() {
        #%logger "-- checking marker file {$INITIALIZATION_COMPLETE_MARKER_FILE}"

        if [ ! -f "${INITIALIZATION_COMPLETE_MARKER_FILE}" ]; then
            Skip "zelta_test_setup_spec.sh must be run first"
        fi
    }

    Before check_marker

    It 'backs up the initial tree'
        When call zelta backup $SRC_POOL/$TREETOP_DSN $TGT_POOL/$BACKUPS_DSN
        The stderr should match pattern "* 230: shift: can't shift that many"
        The status should eq 141
    End

    It 'has valid backup'
        When call zfs list -r "$TGT_POOL"
        The line 2 of output should match pattern "* /$TGT_POOL"
        The line 3 of output should match pattern "* /$TGT_POOL/$BACKUPS_DSN"
        The line 4 of output should match pattern "* /$TGT_POOL/$BACKUPS_DSN/one"
        The line 5 of output should match pattern "* /$TGT_POOL/$BACKUPS_DSN/one/two"
        The line 6 of output should match pattern "* /$TGT_POOL/$BACKUPS_DSN/one/two/three"
    End

End