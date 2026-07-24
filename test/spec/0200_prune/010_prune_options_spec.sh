# WARNING: HandCrafted test
# Embedded Quoting issues corrected by hand in output_for_zprune_keep_12_monthlies()
# Verbose error output for zprune -vv moved to function
# TODO: Test generator needs and update to handle both 

# Auto-generated ShellSpec test file
# Generated at: 2026-07-24 14:41:22 -0400
# Source: 010_prune_options_spec
# WARNING: This file was automatically generated. Manual edits may be lost.

output_for_prune_newest_3_without_guard() {
  while IFS= read -r line; do
    # normalize whitespace, remove leading/trailing spaces
    normalized=$(printf '%s' "$line" | tr -s '[:space:]' ' ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    # check line against expected output
    case "$normalized" in
        "${SANDBOX_ZELTA_SRC_DS}@zelta_yearly_2023-06-20_21.00.00%zelta_daily_2026-06-14_03.00.00")
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

output_for_prune_all_without_guard() {
  while IFS= read -r line; do
    # normalize whitespace, remove leading/trailing spaces
    normalized=$(printf '%s' "$line" | tr -s '[:space:]' ' ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    # check line against expected output
    case "$normalized" in
        "${SANDBOX_ZELTA_SRC_DS}@zelta_yearly_2023-06-20_21.00.00%zelta_daily_2026-06-14_21.00.00")
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

output_for_prune_3_with_guard() {
  while IFS= read -r line; do
    # normalize whitespace, remove leading/trailing spaces
    normalized=$(printf '%s' "$line" | tr -s '[:space:]' ' ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    # check line against expected output
    case "$normalized" in
        "${SANDBOX_ZELTA_SRC_DS}@zelta_yearly_2023-06-20_21.00.00%zelta_daily_2026-06-13_21.00.00")
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

output_for_prune_all_synced() {
  while IFS= read -r line; do
    # normalize whitespace, remove leading/trailing spaces
    normalized=$(printf '%s' "$line" | tr -s '[:space:]' ' ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    # check line against expected output
    case "$normalized" in
        "${SANDBOX_ZELTA_SRC_DS}@zelta_yearly_2023-06-20_21.00.00%zelta_daily_2026-06-14_15.00.00")
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

output_for_prune_grid_weekly() {
  while IFS= read -r line; do
    # normalize whitespace, remove leading/trailing spaces
    normalized=$(printf '%s' "$line" | tr -s '[:space:]' ' ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    # check line against expected output
    case "$normalized" in
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2026-06-08_03.00.00%zelta_daily_2026-06-14_09.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_monthly_2026-06-01_21.00.00%zelta_daily_2026-06-06_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2026-05-25_21.00.00%zelta_daily_2026-05-30_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2026-05-18_21.00.00%zelta_daily_2026-05-23_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2026-05-12_21.00.00%zelta_daily_2026-05-16_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2026-05-06_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2026-04-27_21.00.00%zelta_daily_2026-04-30_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2026-04-21_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2026-04-15_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2026-04-06_21.00.00%zelta_daily_2026-04-09_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2026-03-31_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2026-03-25_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2026-03-16_21.00.00%zelta_daily_2026-03-19_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2026-03-10_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2026-03-04_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2026-02-23_21.00.00%zelta_daily_2026-02-26_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2026-02-17_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2026-02-11_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_monthly_2026-02-02_21.00.00%zelta_daily_2026-02-05_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2026-01-27_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2026-01-21_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2026-01-12_21.00.00%zelta_daily_2026-01-15_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2026-01-06_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2025-12-31_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2025-12-22_21.00.00%zelta_daily_2025-12-25_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_weekly_2025-12-16_21.00.00")
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

output_for_prune_keep_12_monthlies() {
  while IFS= read -r line; do
    # normalize whitespace, remove leading/trailing spaces
    normalized=$(printf '%s' "$line" | tr -s '[:space:]' ' ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    # check line against expected output
    case "$normalized" in
        "${SANDBOX_ZELTA_SRC_DS}@zelta_monthly_2023-07-04_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_monthly_2023-08-01_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_monthly_2023-09-12_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_monthly_2023-10-10_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_monthly_2023-11-07_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_monthly_2023-12-05_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_monthly_2024-02-13_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_monthly_2024-03-12_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_monthly_2024-04-09_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_monthly_2024-05-07_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_monthly_2024-06-04_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_monthly_2024-07-02_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_monthly_2024-08-13_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_monthly_2024-09-10_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_monthly_2024-10-08_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_monthly_2024-11-05_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_monthly_2024-12-03_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_monthly_2025-02-11_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_monthly_2025-03-11_21.00.00"|\
        "${SANDBOX_ZELTA_SRC_DS}@zelta_monthly_2025-04-08_21.00.00")
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

output_for_zprune_keep_12_monthlies() {
  while IFS= read -r line; do
    # normalize whitespace, remove leading/trailing spaces
    normalized=$(printf '%s' "$line" | tr -s '[:space:]' ' ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
    # check line against expected output
    case "$normalized" in
        "Preparing to prune \"${SANDBOX_ZELTA_SRC_EP}\" using the following commands:"|\
        "ssh dever@uvm1 \"zfs destroy '${SANDBOX_ZELTA_SRC_DS}@zelta_monthly_2023-07-04_21.00.00,zelta_monthly_2023-08-01_21.00.00,zelta_monthly_2023-09-12_21.00.00,zelta_monthly_2023-10-10_21.00.00,zelta_monthly_2023-11-07_21.00.00,zelta_monthly_2023-12-05_21.00.00,zelta_monthly_2024-02-13_21.00.00,zelta_monthly_2024-03-12_21.00.00,zelta_monthly_2024-04-09_21.00.00,zelta_monthly_2024-05-07_21.00.00,zelta_monthly_2024-06-04_21.00.00,zelta_monthly_2024-07-02_21.00.00,zelta_monthly_2024-08-13_21.00.00,zelta_monthly_2024-09-10_21.00.00,zelta_monthly_2024-10-08_21.00.00,zelta_monthly_2024-11-05_21.00.00,zelta_monthly_2024-12-03_21.00.00,zelta_monthly_2025-02-11_21.00.00,zelta_monthly_2025-03-11_21.00.00,zelta_monthly_2025-04-08_21.00.00'\""|\
        ""|\
        "20 snapshots (12% of 167) will be destroyed"|\
        "2.2M total reclaimed (6% of 35.0M)")
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

expected_zprune_error() { %text
  #|debug: `zelta ipc-run prune`
  #|debug: `*"zfs destroy 'apool/treetop@zelta_monthly_2023-07-04_21.00.00,zelta_monthly_2023-08-01_21.00.00,zelta_monthly_2023-09-12_21.00.00,zelta_monthly_2023-10-10_21.00.00,zelta_monthly_2023-11-07_21.00.00,zelta_monthly_2023-12-05_21.00.00,zelta_monthly_2024-02-13_21.00.00,zelta_monthly_2024-03-12_21.00.00,zelta_monthly_2024-04-09_21.00.00,zelta_monthly_2024-05-07_21.00.00,zelta_monthly_2024-06-04_21.00.00,zelta_monthly_2024-07-02_21.00.00,zelta_monthly_2024-08-13_21.00.00,zelta_monthly_2024-09-10_21.00.00,zelta_monthly_2024-10-08_21.00.00,zelta_monthly_2024-11-05_21.00.00,zelta_monthly_2024-12-03_21.00.00,zelta_monthly_2025-02-11_21.00.00,zelta_monthly_2025-03-11_21.00.00,zelta_monthly_2025-04-08_21.00.00'"`
}

Describe 'Test prune options' prune-scenario:10
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

  It "restores golden pools" prune-scenario:10-restore
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

  It "prune keep 3 without guard - run zelta prune --prune-num=3 --no-prune-guard \"$SANDBOX_ZELTA_SRC_EP\""
    When run zelta prune --prune-num=3 --no-prune-guard "$SANDBOX_ZELTA_SRC_EP"
    The output should satisfy output_for_prune_newest_3_without_guard
    The status should be success
  End

  It "prune all without guard - run zelta prune --prune-num=0 --no-prune-guard \"$SANDBOX_ZELTA_SRC_EP\""
    When run zelta prune --prune-num=0 --no-prune-guard "$SANDBOX_ZELTA_SRC_EP"
    The output should satisfy output_for_prune_all_without_guard
    The status should be success
  End

  It "prune 3 with guard - run zelta prune --prune-num=3 \"$SANDBOX_ZELTA_SRC_EP\" \"$SANDBOX_ZELTA_TGT_EP\""
    When run zelta prune --prune-num=3 "$SANDBOX_ZELTA_SRC_EP" "$SANDBOX_ZELTA_TGT_EP"
    The output should satisfy output_for_prune_3_with_guard
    The status should be success
  End

  It "prune all with unsynced guard - run zelta prune --prune-num=0 --prune-guard=unsynced \"$SANDBOX_ZELTA_SRC_EP\" \"$SANDBOX_ZELTA_TGT_EP\""
    When run zelta prune --prune-num=0 --prune-guard=unsynced "$SANDBOX_ZELTA_SRC_EP" "$SANDBOX_ZELTA_TGT_EP"
    The output should satisfy output_for_prune_all_synced
    The status should be success
  End

  It "prune all with unsynced guard - run zelta prune --prune-grid=1week \"$SANDBOX_ZELTA_SRC_EP\" \"$SANDBOX_ZELTA_TGT_EP\""
    When run zelta prune --prune-grid=1week "$SANDBOX_ZELTA_SRC_EP" "$SANDBOX_ZELTA_TGT_EP"
    The output should satisfy output_for_prune_grid_weekly
    The status should be success
  End

  It "check prune time 1 day daily count - call systime_cmd_count_lines zelta prune --no-ranges --include=\"@zelta_daily_*\" --prune-time=1day \"$SANDBOX_ZELTA_SRC_EP\" \"$SANDBOX_ZELTA_TGT_EP\""
    When call systime_cmd_count_lines zelta prune --no-ranges --include="@zelta_daily_*" --prune-time=1day "$SANDBOX_ZELTA_SRC_EP" "$SANDBOX_ZELTA_TGT_EP"
    The output should include "$EXPECTED_PRUNE_DAILY_1_DAY_COUNT"
    The status should be success
  End

  It "check prune time 30 day daily count - call systime_cmd_count_lines zelta prune --no-ranges --include=\"@zelta_daily_*\" --prune-time=30day \"$SANDBOX_ZELTA_SRC_EP\" \"$SANDBOX_ZELTA_TGT_EP\""
    When call systime_cmd_count_lines zelta prune --no-ranges --include="@zelta_daily_*" --prune-time=30day "$SANDBOX_ZELTA_SRC_EP" "$SANDBOX_ZELTA_TGT_EP"
    The output should include "$EXPECTED_PRUNE_DAILY_30_DAY_COUNT"
    The status should be success
  End

  It "prune monthlies keep 12 - run zelta prune --no-ranges --include=\"@zelta_monthly_*\" --prune-num=12 \"$SANDBOX_ZELTA_SRC_EP\" \"$SANDBOX_ZELTA_TGT_EP\""
    When run zelta prune --no-ranges --include="@zelta_monthly_*" --prune-num=12 "$SANDBOX_ZELTA_SRC_EP" "$SANDBOX_ZELTA_TGT_EP"
    The output should satisfy output_for_prune_keep_12_monthlies
    The status should be success
  End

  It "zprune monthlies keep 12 - run zprune -vv -f --no-ranges --include=\"@zelta_monthly_*\" --prune-num=12 \"$SANDBOX_ZELTA_SRC_EP\" \"$SANDBOX_ZELTA_TGT_EP\""
    When run zprune -vv -f --no-ranges --include="@zelta_monthly_*" --prune-num=12 "$SANDBOX_ZELTA_SRC_EP" "$SANDBOX_ZELTA_TGT_EP"
    The output should satisfy output_for_zprune_keep_12_monthlies
    The error should match pattern "$(expected_zprune_error)"
    The status should be success
  End

  It "check monthlies count is 12 - call systime_cmd_count_lines zelta prune --no-ranges --prune-guard=none --include=\"@zelta_monthly_*\" --prune-num=0 \"$SANDBOX_ZELTA_SRC_EP\" \"$SANDBOX_ZELTA_TGT_EP\""
    When call systime_cmd_count_lines zelta prune --no-ranges --prune-guard=none --include="@zelta_monthly_*" --prune-num=0 "$SANDBOX_ZELTA_SRC_EP" "$SANDBOX_ZELTA_TGT_EP"
    The output should include "12"
    The status should be success
  End

  It "check value of ZELTA_SYSTIME env var - run \"${SHELLSPEC_HELPERDIR}/zelta_systime_env_var_check.sh\"" prune-scenario:10-timecheck
    When run "${SHELLSPEC_HELPERDIR}/zelta_systime_env_var_check.sh"
    The output should equal "ZELTA_SYSTIME: {$ZELTA_SYSTIME_VALUE}"
    The status should be success
  End

  It "teardown golden pools" prune-scenario:10-teardown
    When call teardown_pools
    The status should be success
  End

End
