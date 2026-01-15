# Option parsing validation tests for Zelta
# Configurable endpoints - override via environment or test_env.sh
#
# Usage:
#   # With defaults (local testpool)
#   shellspec spec/bin/opts_test/opts_spec.sh
#
#   # With remote endpoints
#   SRC_ENDPOINT=user@host:pool/src TGT_ENDPOINT=backupuser@backuphost:backuppool/tgt shellspec spec/bin/opts_test/opts_spec.sh

# Load configurable environment
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "${SCRIPT_DIR}/test_env.sh" ]; then
  . "${SCRIPT_DIR}/test_env.sh"
fi

# Fallback defaults if test_env.sh not loaded or vars not set
: "${SRC_ENDPOINT:=testpool/source}"
: "${TGT_ENDPOINT:=testpool/target}"
: "${CLONE_ENDPOINT:=${SRC_ENDPOINT}_clone}"
: "${CLONE_ENDPOINT_INVALID:=otherhost:differentpool/clone}"
: "${TEST_SNAP_NAME:=test_snapshot}"
: "${TEST_DEPTH:=2}"
: "${TEST_EXCLUDE:=*/swap,@*_hourly}"

Describe "Option Parsing Validation"

  Describe "zelta backup with comprehensive options"
    It "parses all major options and produces valid JSON output"
      When run zelta backup \
        --dryrun \
        --depth "$TEST_DEPTH" \
        --exclude "$TEST_EXCLUDE" \
        --snap-name "$TEST_SNAP_NAME" \
        --snapshot \
        --intermediate \
        --resume \
        --push \
        --send-default '-Lce' \
        --send-raw '-Lw' \
        --send-new '-p' \
        --recv-default '' \
        --recv-top '-o readonly=on' \
        --recv-fs '-u -x mountpoint -o canmount=noauto' \
        --recv-vol '-o volmode=none' \
        -o 'compression=lz4' \
        -x 'mountpoint' \
        --json \
        "$SRC_ENDPOINT" "$TGT_ENDPOINT"
      The status should equal 0
      The output should include '"sourceEndpoint":'
      The output should include '"targetEndpoint":'
      The output should include '"replicationStreamsSent":'
      The stderr should not include "error"
      The stderr should not include "invalid"
    End
  End

  Describe "zelta backup with alternative option forms"
    It "parses short options and alternative flags"
      When run zelta backup \
        -n \
        -qq \
        -d 1 \
        -X '/tmp,*/cache' \
        -i \
        --no-resume \
        --pull \
        --no-snapshot \
        -L \
        --largeblock \
        --compressed \
        --embed \
        --props \
        --raw \
        -u \
        "$SRC_ENDPOINT" "$TGT_ENDPOINT"
      The status should equal 0
      The stderr should equal ""
    End
  End

  Describe "zelta backup with override options"
    It "parses send and recv override options"
      When run zelta backup \
        --dryrun \
        -qq \
        --send-override '-Lce' \
        --recv-override '-o readonly=on' \
        --recv-pipe 'cat' \
        "$SRC_ENDPOINT" "$TGT_ENDPOINT"
      The status should equal 0
      The stderr should equal ""
    End
  End

  Describe "zelta match options"
    It "parses match-specific options and produces output"
      When run zelta match \
        -H \
        -p \
        -o 'ds_suffix,match,xfer_size' \
        --written \
        --time \
        -d "$TEST_DEPTH" \
        -X '*/swap' \
        "$SRC_ENDPOINT" "$TGT_ENDPOINT"
      The status should equal 0
      The output should be defined
    End
  End

  Describe "zelta snapshot options"
    It "parses snapshot options in dryrun mode"
      When run zelta snapshot \
        --dryrun \
        -qq \
        --snap-name 'manual_test' \
        -d 1 \
        "$SRC_ENDPOINT"
      The status should equal 0
    End
  End

  Describe "zelta clone options"
    It "parses clone options in dryrun mode"
      When run zelta clone \
        --dryrun \
        -qq \
        --snapshot \
        --snap-name 'clone_snap' \
        -d "$TEST_DEPTH" \
        "$SRC_ENDPOINT" "$CLONE_ENDPOINT"
      The status should equal 0
    End
  End

  Describe "zelta clone endpoint validation"
    It "rejects clone to mismatched pool/host"
      When run zelta clone \
        --dryrun \
        -qq \
        "$SRC_ENDPOINT" "$CLONE_ENDPOINT_INVALID"
      The status should not equal 0
      The stderr should include "cannot clone"
    End
  End

  Describe "zelta rotate options"
    It "parses rotate options in dryrun mode"
      When run zelta rotate \
        --dryrun \
        -qq \
        --no-snapshot \
        --push \
        "$SRC_ENDPOINT" "$TGT_ENDPOINT"
      The status should equal 0
    End
  End

  Describe "zelta revert options"
    It "parses revert options in dryrun mode"
      When run zelta revert \
        --dryrun \
        -qq \
        "$SRC_ENDPOINT"
      The status should equal 0
    End
  End

  Describe "zelta prune options"
    It "parses prune options"
      When run zelta prune \
        --dryrun \
        -qq \
        --keep-snap-days 90 \
        --keep-snap-num 100 \
        --no-ranges \
        -d "$TEST_DEPTH" \
        -X '*/tmp' \
        "$SRC_ENDPOINT" "$TGT_ENDPOINT"
      The status should equal 0
    End
  End

  Describe "deprecated option warnings"
    It "warns about deprecated -s option"
      When run zelta backup --dryrun -qq -s "$SRC_ENDPOINT" "$TGT_ENDPOINT"
      The stderr should include "deprecated"
    End

    It "warns about deprecated -t option"
      When run zelta backup --dryrun -qq -t "$SRC_ENDPOINT" "$TGT_ENDPOINT"
      The stderr should include "deprecated"
    End

    It "warns about deprecated -T option"
      When run zelta backup --dryrun -qq -T "$SRC_ENDPOINT" "$TGT_ENDPOINT"
      The stderr should include "deprecated"
    End
  End

  Describe "invalid option handling"
    It "rejects invalid options gracefully"
      When run zelta backup --dryrun -qq --invalid-option-xyz "$SRC_ENDPOINT" "$TGT_ENDPOINT"
      The status should not equal 0
      The stderr should include "invalid"
    End

    It "rejects deprecated --initiator option"
      When run zelta backup --dryrun -qq --initiator PULL "$SRC_ENDPOINT" "$TGT_ENDPOINT"
      The status should not equal 0
      The stderr should include "deprecated"
    End

    It "rejects deprecated --progress option"
      When run zelta backup --dryrun -qq --progress "$SRC_ENDPOINT" "$TGT_ENDPOINT"
      The status should not equal 0
      The stderr should include "deprecated"
    End
  End

End
