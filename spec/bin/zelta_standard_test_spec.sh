
#export SRC_POOL=apool
#export TGT_POOL=bpool
#export TREETOP_DSN=treetop
#export BACKUPS_DSN=backups

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


global_setup_function() {
    %putsn "global_setup_function"
    %putsn "before: SRC_POOL=$SRC_POOL, TGT_POOL=$TGT_POOL"
    #export SRC_SVR=dever@fzfsdev:
    #export TGT_SVR=dever@fzfsdev:
    #SRC_POOL='apool'
    #TGT_POOL='bpool'
    export TREETOP_DSN='treetop'
    export BACKUPS_DSN='backups'
    export SOURCE=${SRC_SVR}${SRC_POOL}/${TREETOP_DSN}
    export TARGET=${TGT_SVR}${TGT_POOL}/${BACKUPS_DSN}
    export SRC_TREE="$SRC_POOL/$TREETOP_DSN"
    export TGT_TREE="$TGT_POOL/$BACKUPS_DSN/$TREETOP_DSN"
    export ALL_DATASETS="one/two/three"
    %putsn "after: SRC_POOL=$SRC_POOL, TGT_POOL=$TGT"
    CWD=$(pwd)
    #sudo /home/dever/src/repos/zelta/spec/initialize/setup_simple_snap_tree.sh
    #./spec/initializize/setup_simple_snap_tree.sh
    %putsn "current dir {$CWD}"
    %putsn "current dir {$CWD}"
    %putsn "current dir {$CWD}"
    %putsn "current dir {$CWD}"
    %putsn "current dir {$CWD}"
}


#BeforeAll 'global_setup_function'


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

Describe 'zelta rotate'
    It 'rotates the backed up tree'
        When call zelta rotate $SOURCE $TARGET
        # I saw this error once and not again, I'm not sure how to reproduce it
        The line 1 of output should match pattern "action requires a target delta; snapshotting: *"

        # Check for gawk warning on Linux only
        if [ "$(uname -s)" = "Linux" ]; then
            The line 1 of stderr should equal "warning: 'gawk' bug detected, using 'mawk'"
        fi

        # Check for expected error messages (order-independent)
        # TODO: consider making these checks less brittle/specific by check for a more general message
        The stderr should include "warning: insufficient snapshots; performing full backup for 1 datasets"
        The stderr should include "error: to perform a full backup, rename the target dataset or sync to an empty target"
        The stderr should include "error: top source dataset 'apool/treetop' or its origin must match the target for rotation to continue"

        #The stdout should be blank
        The stderr should not be blank
        The status should eq 1
    End
End