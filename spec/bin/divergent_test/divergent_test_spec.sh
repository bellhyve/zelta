. spec/bin/divergent_test/divergent_test_env.sh

# Custom validation functions


match_after_first_backup_output() {
  while IFS= read -r line; do
      # normalize whitespace, remove leading/trailing spaces
      normalized=$(echo "$line" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//')

        case "${normalized}" in
            "source is written; snapshotting: @zelta_"*)
                # New snapshot created on source
                ;;
            "syncing 9 datasets")
                # Starting sync operation
                ;;
            "no source: $TGT_TREE/sub1/kid")
                # Dataset exists on target but not on source
                ;;
            "target snapshots beyond the source match: $TGT_TREE/sub2")
                # Target has snapshots newer than source's latest matching snapshot
                ;;
            "target snapshots beyond the source match: $TGT_TREE/sub2/orphan")
                # Target has snapshots newer than source's latest matching snapshot
                ;;
            "target snapshots beyond the source match: $TGT_TREE/sub3/space name")
                # Target has snapshots newer than source's latest matching snapshot
                ;;
            "no snapshot; target diverged: $TGT_TREE/vol1")
                # No common snapshot found; target has diverged from source
                ;;
            "15K sent, 5 streams received in 0.09 seconds")
                # Summary statistics
                ;;
           *)
             echo "Unexpected line format: $line" >&2
             return 1
             ;;
     esac
  done
}


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
    #[ "$line" = "NAME                             USED  AVAIL  REFER  MOUNTPOINT" ] && continue
    #[[ "$line" = "NAME"*"USED"*"AVAIL"*"REFER"*"MOUNTPOINT" ]] && continue

    # Pattern: NAME * * * MOUNTPOINT
    case "$line" in
      "NAME"*"USED"*"AVAIL"*"REFER"*"MOUNTPOINT") continue ;;
      apool*"/apool"|\
      $SRC_TREE*"/$SRC_TREE"|\
      $SRC_TREE/sub1*"/$SRC_TREE/sub1"|\
      $SRC_TREE/sub1/child*"/$SRC_TREE/sub1/child"|\
      $SRC_TREE/sub2*"/$SRC_TREE/sub2"|\
      $SRC_TREE/sub2/orphan*"/$SRC_TREE/sub2/orphan"|\
      $SRC_TREE/sub3*"/$SRC_TREE/sub3"|\
      $SRC_TREE/sub3/space\ name*"/$SRC_TREE/sub3/space name"|\
      $SRC_TREE/vol1*"-"|\
      bpool*"/bpool"|\
      bpool/backups*"/bpool/backups"|\
      $TGT_TREE*"/$TGT_TREE"|\
      $TGT_TREE/sub1*"/$TGT_TREE/sub1"|\
      $TGT_TREE/sub1/kid*"/$TGT_TREE/sub1/kid"|\
      $TGT_TREE/sub2*"/$TGT_TREE/sub2"|\
      $TGT_TREE/sub2/orphan*"/$TGT_TREE/sub2/orphan"|\
      $TGT_TREE/sub3*"/$TGT_TREE/sub3"|\
      $TGT_TREE/sub3/space\ name*"/$TGT_TREE/sub3/space name"|\
      $TGT_TREE/vol1*"-"|\
      $TGT_SETUP*"/$TGT_SETUP"|\
      $TGT_SETUP/sub1*"/$TGT_SETUP/sub1"|\
      $TGT_SETUP/sub2*"/$TGT_SETUP/sub2"|\
      $TGT_SETUP/sub2/orphan*"/$TGT_SETUP/sub2/orphan"|\
      $TGT_SETUP/sub3*"/$TGT_SETUP/sub3"|\
      $TGT_SETUP/sub3/space\ name*"/$TGT_SETUP/sub3/space name"|\
      $TGT_SETUP/vol1*"-"|\
      ${TGT_SETUP}_set*"/${TGT_SETUP}_set"|\
      ${TGT_SETUP}_set/sub1*"/${TGT_SETUP}_set/sub1"|\
      ${TGT_SETUP}_set/sub2*"/${TGT_SETUP}_set/sub2"|\
      ${TGT_SETUP}_set/sub2/orphan*"/${TGT_SETUP}_set/sub2/orphan"|\
      ${TGT_SETUP}_set/sub3*"/${TGT_SETUP}_set/sub3"|\
      ${TGT_SETUP}_set/sub3/space\ name*"${TGT_SETUP}_set/sub3/space name"|\
      ${TGT_SETUP}_set/vol1*"-")
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



Describe 'backup, rotate, revert, rotate'
    It "backups $SOURCE to $TARGET"
       When call zelta backup $SOURCE $TARGET
       The output should satisfy match_after_first_backup_output
    End
End
