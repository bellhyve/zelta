
Describe 'Test prune options' prune-scenario:30
  Include "${SHELLSPEC_HELPERDIR}/golden_pool_helper.sh"
  

  ZELTA_SYSTIME_VALUE='date -d "2026-06-14 00:00:00 EDT" +%s'
  EXPECTED_SNAPSHOTS=168
  EXPECTED_PRUNE_DAILY_1_DAY_COUNT=65
  EXPECTED_PRUNE_DAILY_30_DAY_COUNT=24
  PRUNE_HOOK_DEBUG_LOG="/tmp/zelta_sandbox_prune_hooks_log.txt"
  
  set_zelta_systime() {
     #export ZELTA_SYSTIME='date -d "2026-06-14 00:00:00 EDT" +%s'
     export ZELTA_SYSTIME="$ZELTA_SYSTIME_VALUE"
     %logger "ZELTA_SYSTIME=$ZELTA_SYSTIME"
  }
  
  # don't use ShellSpec Before/After All hooks, they are executed even when this spec isn't selected
  # before / after hooks are not It clauses 'restores golden pools' and 'removes golden pools' respectively
  # TODO: after testing redirect stdout to /dev/null, stderr output is intended to fail the tests
  setup_pools() { make_golden_pools > $PRUNE_HOOK_DEBUG_LOG; }
  teardown_pools() { teardown_golden_pools >> $PRUNE_HOOK_DEBUG_LOG; }
  
  snapshot_count() {
    out=$(tgt_exec zfs list -r -t snapshot "$1") || return
    count=$(printf '%s\n' "$out" | wc -l)
    #[ "$count" -eq "$expected" ]
    printf 'found %s snapshots\n' "$count"
  }

  # run the command represented by the $@ in a shell with ZELTA_SYSTIME override
  systime_cmd_count_lines() {
    # running the
    out=$(set_zelta_systime; "$@")
    count=$(printf '%s\n' "$out" | wc -l)
    cmd="$@"
    %logger "found count $count"
    printf 'command {%s}\n\t returned line count %s\n' "$cmd" "$count"
  }

  Skip if 'SANDBOX_ZELTA_SRC_EP undefined' test -z "$SANDBOX_ZELTA_SRC_EP"
  Skip if 'SANDBOX_ZELTA_TGT_EP undefined' test -z "$SANDBOX_ZELTA_TGT_EP"

  BeforeRun  set_zelta_systime

  It "restores golden pools" prune-scenario:30-restore
    When call setup_pools
    The status should be success
  End

  It "${SANDBOX_ZELTA_SRC_EP} has $EXPECTED_SNAPSHOTS snapshots"
    When call snapshot_count "$SANDBOX_ZELTA_TGT_DS"
    The output should include "$EXPECTED_SNAPSHOTS"
    The status should be success
  End

  It "${SANDBOX_ZELTA_TGT_EP} has $EXPECTED_SNAPSHOTS snapshots"
    When call snapshot_count "$SANDBOX_ZELTA_TGT_DS"
    The output should include "$EXPECTED_SNAPSHOTS"
    The status should be success
  End

  It "check prune time 1 day daily count - call cmd_count_lines zelta prune --no-ranges --include=\"@zelta_daily_*\" --prune-time=1day \"$SANDBOX_ZELTA_SRC_EP\" \"$SANDBOX_ZELTA_TGT_EP\""
    BeforeRun  set_zelta_systime
    When call systime_cmd_count_lines zelta prune --no-ranges --include="@zelta_daily_*" --prune-time=1day "$SANDBOX_ZELTA_SRC_EP" "$SANDBOX_ZELTA_TGT_EP"
    The output should include "$EXPECTED_PRUNE_DAILY_1_DAY_COUNT"
    The status should be success
  End

  It "check $ZELTA_SYSTIME value" prune-scenario:timecheck
    When run "${SHELLSPEC_HELPERDIR}/time_check.sh"
    #The output should equal 'ZELTA_SYSTIME: {date -d "2026-06-14 00:00:00 EDT" +%s}'
    The output should equal "ZELTA_SYSTIME: {$ZELTA_SYSTIME_VALUE}"
    The status should be success
  End

  It "teardown golden pools" prune-scenario:30-teardown
    When call teardown_pools
    The status should be success
  End

End
