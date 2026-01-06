. spec/bin/divergent_test/divergent_test_env.sh
. spec/lib/common.sh

# Custom validation functions

match_after_divergent_snapshots_output() {
  while IFS= read -r line; do
      # normalize whitespace, remove leading/trailing spaces
      normalized=$(echo "$line" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//')

     case "$normalized" in
       "DS_SUFFIX MATCH SRC_LAST TGT_LAST INFO"|\
       "[treetop] @go @go @go up-to-date"|\
       "/sub1 @go @go @go up-to-date"|\
       "/sub1/child - - - syncable (full)"|\
       "/sub1/kid - - - no source (target only)"|\
       "/sub2 @go @two @two blocked sync: target diverged"|\
       "/sub2/orphan @go @two @two blocked sync: target diverged"|\
       "/sub3 @go @two @go syncable (incremental)"|\
       "/sub3/space name @go @two @blocker blocked sync: target diverged"|\
       "/vol1 - @go - blocked sync: no target snapshots"|\
       "2 up-to-date, 2 syncable, 5 blocked"|\
       "9 total datasets compared")
         # Pattern matches
         ;;
       *)
         echo "Unexpected line format: $line" >&2
         return 1
         ;;
     esac
  done
}



divergent_initial_match_output() {
  while IFS= read -r line; do
      # normalize whitespace, remove leading/trailing spaces
      normalized=$(echo "$line" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//')

      case "$normalized" in
        "DS_SUFFIX MATCH SRC_LAST TGT_LAST INFO"|\
        "[treetop] @go @go @go up-to-date"|\
        "/sub1 @go @go @go up-to-date"|\
        "/sub1/child - - - syncable (full)"|\
        "/sub1/kid - - - no source (target only)"|\
        "/sub2 @go @go @go up-to-date"|\
        "/sub2/orphan @go @go @go up-to-date"|\
        "/sub3 @go @go @go up-to-date"|\
        "/sub3/space name @go @go @blocker blocked sync: target diverged"|\
        "/vol1 - @go - blocked sync: no target snapshots"|\
        "5 up-to-date, 1 syncable, 3 blocked"|\
        "9 total datasets compared")
          # Pattern matches
          ;;
        *)
          echo "Unexpected line format: $line" >&2
          return 1
          ;;
      esac
  done
}



validate_divergent_snap_tree_zfs_output() {
  while IFS= read -r line; do
    # Skip header line
    [ "$line" = "NAME                             USED  AVAIL  REFER  MOUNTPOINT" ] && continue

    # Pattern: NAME * * * MOUNTPOINT
    case "$line" in
      apool*"/apool"|\
      apool/treetop*"/apool/treetop"|\
      apool/treetop/sub1*"/apool/treetop/sub1"|\
      apool/treetop/sub1/child*"/apool/treetop/sub1/child"|\
      apool/treetop/sub2*"/apool/treetop/sub2"|\
      apool/treetop/sub2/orphan*"/apool/treetop/sub2/orphan"|\
      apool/treetop/sub3*"/apool/treetop/sub3"|\
      apool/treetop/sub3/space\ name*"/apool/treetop/sub3/space name"|\
      apool/treetop/vol1*"-"|\
      bpool*"/bpool"|\
      bpool/backups*"/bpool/backups"|\
      bpool/backups/treetop*"/bpool/backups/treetop"|\
      bpool/backups/treetop/sub1*"/bpool/backups/treetop/sub1"|\
      bpool/backups/treetop/sub1/kid*"/bpool/backups/treetop/sub1/kid"|\
      bpool/backups/treetop/sub2*"/bpool/backups/treetop/sub2"|\
      bpool/backups/treetop/sub2/orphan*"/bpool/backups/treetop/sub2/orphan"|\
      bpool/backups/treetop/sub3*"/bpool/backups/treetop/sub3"|\
      bpool/backups/treetop/sub3/space\ name*"/bpool/backups/treetop/sub3/space name"|\
      bpool/backups/treetop/vol1*"-"|\
      bpool/temp*"/bpool/temp"|\
      bpool/temp/sub1*"/bpool/temp/sub1"|\
      bpool/temp/sub2*"/bpool/temp/sub2"|\
      bpool/temp/sub2/orphan*"/bpool/temp/sub2/orphan"|\
      bpool/temp/sub3*"/bpool/temp/sub3"|\
      bpool/temp/sub3/space\ name*"/bpool/temp/sub3/space name"|\
      bpool/temp/vol1*"-"|\
      bpool/temp_set*"/bpool/temp_set"|\
      bpool/temp_set/sub1*"/bpool/temp_set/sub1"|\
      bpool/temp_set/sub2*"/bpool/temp_set/sub2"|\
      bpool/temp_set/sub2/orphan*"/bpool/temp_set/sub2/orphan"|\
      bpool/temp_set/sub3*"/bpool/temp_set/sub3"|\
      bpool/temp_set/sub3/space\ name*"/bpool/temp_set/sub3/space name"|\
      bpool/temp_set/vol1*"-")
        # Pattern matches
        ;;
      *)
        echo "Unexpected line format: $line" >&2
        return 1
        ;;
    esac
  done
}

add_divergent_snapshots() {
    zelta snapshot "$SOURCE"/sub2@two
    zelta snapshot "$TARGET"/sub2@two
}

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

    Describe 'zfs list output validation'
      It 'matches expected pattern for each line'
        When call exec_on "$TGT_SVR" zfs list -r -H $SRC_POOL $TGT_POOL

        The output should satisfy validate_divergent_snap_tree_zfs_output
      End
    End

    Describe 'check initial zelta match state'
      It "initial match has 5 up-to-date, 1 syncable, 3 blocked, with 9 total datasets compared"
        When call zelta match $SOURCE $TARGET
        The output should satisfy divergent_initial_match_output
      End
    End

    Describe 'add incremental source snapshot'
       It "adds $SOURCE/sub3@two snapshot"
         When call zelta snapshot "$SOURCE"/sub3@two
         The output should equal "snapshot created '$SRC_TREE/sub3@two'"
         The stderr should be blank
         The status should eq 0
       End
    End

    Describe 'add divergent snapshots of same name'
       It "adds divergent snapshots for $SOURCE/sub2@two and $TARGET/sub2@two"
         When call add_divergent_snapshots
         The line 1 of output should equal "snapshot created '$SRC_TREE/sub2@two'"
         The line 2 of output should equal "snapshot created '$TGT_TREE/sub2@two'"
         The stderr should be blank
         The status should eq 0
       End
    End

    Describe 'check zelta match after divergent snapshots'
      It "after divergent snapshot match has 2 up-to-date, 2 syncable, 5 blocked, with 9 total datasets compared"
        When call zelta match $SOURCE $TARGET
        The output should satisfy match_after_divergent_snapshots_output
      End
    End
End
