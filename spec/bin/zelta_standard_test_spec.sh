
match_either() {
    case $SHELLSPEC_SUBJECT in
        "$1"|"$2") 
    	return 0 
    	;;
        *) 
    	return 1 
    	;;
    esac
}



Describe 'confirm zfs setup'
    before_all() {
        %logger "-- before_all: confirm zfs setup"
    }

    after_all() {
        %logger "-- after_all: confirm zfs setup"
    }

    #BeforeAll before_all
    #AfterAll  after_all

    It "has good initial SRC_POOL:{$SRC_POOL} simple snap tree"
        When call zfs list -r "$SRC_POOL"
        The line 2 of output should match pattern "* /$SRC_POOL"
        The line 3 of output should match pattern "* /$SRC_POOL/$TREETOP_DSN"
        The line 4 of output should match pattern "* /$SRC_POOL/$TREETOP_DSN/one"
        The line 5 of output should match pattern "* /$SRC_POOL/$TREETOP_DSN/one/two"
        The line 6 of output should match pattern "* /$SRC_POOL/$TREETOP_DSN/one/two/three"
     End

     It "has good initial TGT_POOL:{$TGT_POOL} simple snap tree"
         When call zfs list -r "$TGT_POOL"
         The line 2 of output should match pattern "* /$TGT_POOL"
     End
End

Describe 'try backup'

    It 'backs up the initial tree'
        When call zelta backup $SRC_POOL/$TREETOP_DSN $TGT_POOL/$BACKUPS_DSN
        The line 1 of output should match pattern "source is written; snapshotting: @zelta_*"
        The line 2 of output should equal "syncing 4 datasets"
        The line 3 of output should equal "no snapshot; target diverged: bpool/backups"
        The line 4 of output should match pattern  "* sent, 3 streams received in *"
	The stderr should satisfy match_either  "warning: 'gawk' bug detected, using 'mawk'" ""
        The stdout should not be blank
        The status should eq 0
    End

    It 'has valid backup'
        When call sudo zfs list -r "$TGT_POOL"
        The line 2 of output should match pattern "* /$TGT_POOL"
        The line 3 of output should match pattern "* /$TGT_POOL/$BACKUPS_DSN"
        The line 4 of output should match pattern "* /$TGT_POOL/$BACKUPS_DSN/one"
        The line 5 of output should match pattern "* /$TGT_POOL/$BACKUPS_DSN/one/two"
        The line 6 of output should match pattern "* /$TGT_POOL/$BACKUPS_DSN/one/two/three"
    End
End

#Describe 'zelta rotate'
#    It 'rotates the backed up tree'
#    When call zelta rotate $SOURCE $TARGET
#End
