# Configurable test environment for opts_test
# Override these via environment variables before running tests
#
# Examples:
#   export SRC_ENDPOINT="user@host:testpool/source"
#   export TGT_ENDPOINT="otheruser@backuphost:backuppool/target"
#
# Or for local testing:
#   export SRC_ENDPOINT="testpool/source"
#   export TGT_ENDPOINT="backuppool/target"
#
# Run tests:
#   shellspec spec/bin/opts_test/opts_spec.sh

# Source endpoint - the dataset tree to back up / match / snapshot
: "${SRC_ENDPOINT:=testpool/source}"

# Target endpoint - where backups go (can be completely different host/pool)
: "${TGT_ENDPOINT:=testpool/target}"

# Clone endpoint - for zelta clone tests
# Must be on same pool as source (user@host:pool must match exactly)
# Default: derive from SRC_ENDPOINT by appending _clone to the dataset path
: "${CLONE_ENDPOINT:=${SRC_ENDPOINT}_clone}"

# Invalid clone endpoint - for testing clone failure on mismatched pool/host
: "${CLONE_ENDPOINT_INVALID:=otherhost:differentpool/clone}"

# Snapshot name for tests that create snapshots
: "${TEST_SNAP_NAME:=test_snapshot}"

# Depth limit for recursive operations (0 = unlimited)
: "${TEST_DEPTH:=2}"

# Exclusion patterns for testing
: "${TEST_EXCLUDE:=*/swap,@*_hourly}"
