
. spec/bin/divergent_test/divergent_test_env.sh
. spec/lib/common.sh

# TODO: setup tests for the following:
## Incremental source
#zelta snapshot "$SRCTREE"/sub3@two
#
## Divergent snapshots of the same name
#zelta snapshot "$SRCTREE"/sub2@two
#zelta snapshot "$TGTTREE"/sub2@two
#
#zelta match $SRCTREE "$TGTTREE"
# Custom validation function
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
End