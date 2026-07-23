# Auto-generated ShellSpec test file
# Generated at: 2026-07-23 17:41:21 -0400
# Source: 000_verify_zfs_permissions_spec
# WARNING: This file was automatically generated. Manual edits may be lost.

output_for_zfs_check_delegation() {
  while IFS= read -r line; do
    # normalize whitespace, remove leading/trailing spaces
    normalized=$(printf '%s' "$line" | tr -s '[:space:]' ' ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    # check line against expected output
    case "$normalized" in
        "NAME PROPERTY VALUE SOURCE"|\
        "apool delegation on default")
        ;;
      *)
        printf "Unexpected line format : %s\n" "$line" >&2
        printf "Comparing to normalized: %s\n" "$normalized" >&2
        return 1
        ;;
    esac
  done
  return 0
}

output_for_zfs_check_allow_permissions() {
  while IFS= read -r line; do
    # normalize whitespace, remove leading/trailing spaces
    normalized=$(printf '%s' "$line" | tr -s '[:space:]' ' ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    # check line against expected output
    case "$normalized" in
        "---- Permissions on ${SANDBOX_ZELTA_SRC_DS} ------------------------------------"|\
        "Local+Descendent permissions:"|\
        "everyone destroy,mount")
        ;;
      *)
        printf "Unexpected line format : %s\n" "$line" >&2
        printf "Comparing to normalized: %s\n" "$normalized" >&2
        return 1
        ;;
    esac
  done
  return 0
}

Describe 'Test zfs delegation and permissions' prune-scenario:00
  Include "${SHELLSPEC_HELPERDIR}/golden_pool_helper.sh"
  
  ZELTA_SYSTIME_VALUE='date -d "2026-06-14 00:00:00 EDT" +%s'
  EXPECTED_SNAPSHOTS=168
  EXPECTED_PRUNE_DAILY_1_DAY_COUNT=65
  EXPECTED_PRUNE_DAILY_30_DAY_COUNT=24
  PRUNE_HOOK_DEBUG_LOG="/tmp/zelta_sandbox_prune_hooks_log.txt"
  
  snapshot_count() {
    out=$(tgt_exec zfs list -r -t snapshot "$1") || return
    count=$(printf '%s\n' "$out" | wc -l)
    #[ "$count" -eq "$expected" ]
    printf 'found %s snapshots\n' "$count"
  }
  
  set_zelta_systime() {
    export ZELTA_SYSTIME="$ZELTA_SYSTIME_VALUE"
    #%logger "ZELTA_SYSTIME=$ZELTA_SYSTIME"
  }
  
  # run the command represented by the $@ in a shell with ZELTA_SYSTIME override
  systime_cmd_count_lines() {
    out=$(set_zelta_systime; "$@")
    count=$(printf '%s\n' "$out" | wc -l)
    cmd="$@"
    #%logger "systime cmd found count $count"
    printf 'command {%s}\n\t returned line count %s\n' "$cmd" "$count"
  }
  
  # WARNING: don't use ShellSpec Before/After All hooks, they are executed even when this spec isn't selected
  # before / after hooks are not It clauses 'restores golden pools' and 'removes golden pools' respectively
  # TODO: after testing redirect stdout to /dev/null, stderr output is intended to fail the tests
  setup_pools() { make_golden_pools > $PRUNE_HOOK_DEBUG_LOG; }
  teardown_pools() { teardown_golden_pools >> $PRUNE_HOOK_DEBUG_LOG; }

  Skip if 'SANDBOX_ZELTA_SRC_EP undefined' test -z "$SANDBOX_ZELTA_SRC_EP"
  Skip if 'SANDBOX_ZELTA_TGT_EP undefined' test -z "$SANDBOX_ZELTA_TGT_EP"

  BeforeRun  set_zelta_systime

  It "restores golden pools" prune-scenario:00-restore
    When call setup_pools
    The status should be success
  End

  It "enables delegation on ${SANDBOX_ZELTA_SRC_POOL} - call src_exec zpool get delegation \"$SANDBOX_ZELTA_SRC_POOL\"" prune-scenario:zfs-check
    When call src_exec zpool get delegation "$SANDBOX_ZELTA_SRC_POOL"
    The output should satisfy output_for_zfs_check_delegation
    The status should be success
  End

  It "grants everyone destroy and mount on ${SANDBOX_ZELTA_SRC_DS}  - call src_exec zfs allow \"$SANDBOX_ZELTA_SRC_DS\"" prune-scenario:zfs-check
    When call src_exec zfs allow "$SANDBOX_ZELTA_SRC_DS"
    The output should satisfy output_for_zfs_check_allow_permissions
    The status should be success
  End

  It "teardown golden pools" prune-scenario:00-teardown
    When call teardown_pools
    The status should be success
  End

End
