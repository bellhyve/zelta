. spec/bin/standard_test/standard_test_env.sh
. spec/lib/common.sh

# valid xtrace usage if found
validate_options() {
    # Direct test - executes if function returns 0 (success)
    if ! check_if_xtrace_usage_valid; then
        echo "xtrace options are not correct" >&2
        echo "to show expectations use --shell bash and bash version >= 4" >&2
        echo "NOTE Use: --xtrace --shell bash" >&2
        return 1
    fi
    return 0
}


# allow for 2 vaild matches for current shellspec line/subject being considered
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

# TODO: is it possible to setup a snap tree on FreeBSD as the backup user?
# TODO: when should this code be removed: left over from an attempt to setup a snap tree prior to start of every test
#global_setup_function() {
#    %putsn "global_setup_function"
#    %putsn "before: SRC_POOL=$SRC_POOL, TGT_POOL=$TGT_POOL"
#    #export SRC_SVR=dever@fzfsdev:
#    #export TGT_SVR=dever@fzfsdev:
#    #SRC_POOL='apool'
#    #TGT_POOL='bpool'
#    export TREETOP_DSN='treetop'
#    export BACKUPS_DSN='backups'
#    export SOURCE=${SRC_SVR}${SRC_POOL}/${TREETOP_DSN}
#    export TARGET=${TGT_SVR}${TGT_POOL}/${BACKUPS_DSN}
#    export SRC_TREE="$SRC_POOL/$TREETOP_DSN"
#    export TGT_TREE="$TGT_POOL/$BACKUPS_DSN/$TREETOP_DSN"
#    export ALL_DATASETS="one/two/three"
#    %putsn "after: SRC_POOL=$SRC_POOL, TGT_POOL=$TGT"
#    CWD=$(pwd)
#    #sudo /home/dever/src/repos/zelta/spec/initialize/setup_simple_snap_tree.sh
#    #./spec/initializize/setup_simple_snap_tree.sh
#    %putsn "current dir {$CWD}"
#    %putsn "current dir {$CWD}"
#    %putsn "current dir {$CWD}"
#    %putsn "current dir {$CWD}"
#    %putsn "current dir {$CWD}"
#}


BeforeAll validate_options

Describe 'confirm zfs setup'
    before_all() {
        %logger "-- before_all: confirm zfs setup"
        echo
    }

    after_all() {
        %logger "-- after_all: confirm zfs setup"
    }

    #BeforeAll before_all
    #AfterAll  after_all

    It "has good initial SRC_POOL:{$SRC_POOL} simple snap tree"
        When call exec_on "$SRC_SVR" zfs list -r "$SRC_POOL"
        The line 2 of output should match pattern "* /$SRC_POOL"
        The line 3 of output should match pattern "* /$SRC_POOL/$TREETOP_DSN"
        The line 4 of output should match pattern "* /$SRC_POOL/$TREETOP_DSN/one"
        The line 5 of output should match pattern "* /$SRC_POOL/$TREETOP_DSN/one/two"
        The line 6 of output should match pattern "* /$SRC_POOL/$TREETOP_DSN/one/two/three"
     End

     It "has good initial TGT_POOL:{$TGT_POOL} simple snap tree"
         When call exec_on "$TGT_SVR" zfs list -r "$TGT_POOL"
         The line 2 of output should match pattern "* /$TGT_POOL"
     End
End

Describe 'try backup'

    It 'backs up the initial tree'
        When call zelta backup $SOURCE $TARGET

        The line 1 of output should match pattern "source is written; snapshotting: @zelta_*"
        The line 2 of output should equal "syncing 4 datasets"
        The line 3 of output should match pattern "* sent, 4 streams received in * seconds"
        The status should eq 0
    End

    It 'has valid backup'
        When call exec_on "$TGT_SVR" zfs list -r "$TGT_POOL"
        The line 2 of output should match pattern "$TGT_POOL * /$TGT_POOL"
        The line 3 of output should match pattern "$TGT_POOL/$BACKUPS_DSN * /$TGT_POOL/$BACKUPS_DSN"
        The line 4 of output should match pattern "$TGT_TREE * /$TGT_TREE"
        The line 5 of output should match pattern "$TGT_TREE/one * /$TGT_TREE/one"
        The line 6 of output should match pattern "$TGT_TREE/one/two * /$TGT_TREE/one/two"
        The line 7 of output should match pattern "$TGT_TREE/one/two/three * /$TGT_TREE/one/two/three"

        The stderr should be blank
        The status should eq 0
    End

    Parameters
      8         '^(apool|bpool)'        $TGT_SVR
      4          apool/treetop          $TGT_SVR
      4          bpool/backups/treetop  $TGT_SVR
    End

    It "has $1 snapshots on ${3:-localhost} ${2:+matching pattern '$2'}"
        When call snapshot_count $1 $2 $3
        The stderr should be blank
        The status should eq 0
    End
End

Describe 'zelta rotate'
    It 'rotates the backed up tree'
        # force snapshot timestamp to be at 1 second in future to prevent backup snapshot conflict
        sleep 1

        When call zelta rotate $SOURCE $TARGET

        # TODO: verify that '$SRC_TREE and TGT_TREE' will work for remotes, or if i need to use $SOURCE and $TARGET instead
        The line 1 of output should match pattern "action requires a snapshot delta; snapshotting: @zelta_*"
        The line 2 of output should match pattern "rotating from source: ${SRC_TREE}@zelta_*"
        The line 3 of output should match pattern "renaming '${TGT_TREE}' to '${TGT_TREE}_zelta_*'"
        The line 4 of output should match pattern "to ensure target is up-to-date, run: zelta backup ${SOURCE} ${TARGET}"
        The line 5 of output should match pattern "* datasets up-to-date"
        The line 6 of output should match pattern "* sent, * streams received in * seconds"
        The stderr should be blank
        The status should eq 0
    End

    Parameters
      16       '^(apool|bpool)'       $TGT_SVR
      8        apool/treetop          $TGT_SVR
      8        bpool/backups/treetop  $TGT_SVR
    End

    It "has $1 snapshots on ${3:-localhost} ${2:+matching pattern '$2'}"
        When call snapshot_count $1 $2 $3
        The stderr should be blank
        The status should eq 0
    End
End
