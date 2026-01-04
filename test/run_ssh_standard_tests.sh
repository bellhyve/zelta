#!/bin/sh
set -e
curdir=$(pwd)
echo "current dir is {$curdir}"

export SRC_SVR="dever@fzfsdev"
export TGT_SVR="dever@fzfsdev"

# NOTE: see remote_test_setup for remote tree setup

echo "Running zelta tests..."
SHELLSPEC_TESTOPT="${SHELLSPEC_TESTOPT:-}"
shellspec -f d "$SHELLSPEC_TESTOPT" ./spec/bin/standard_test/standard_test_spec.sh
#shellspec -f d "$SHELLSPEC_TESTOPT" spec/bin/standard_test/standard_test_spec.sh:@1
#shellspec -f d "$SHELLSPEC_TESTOPT" spec/bin/standard_test/standard_test_spec.sh:@2
#shellspec -f d "$SHELLSPEC_TESTOPT" spec/bin/standard_test/standard_test_spec.sh:@3

echo ""
echo "✓ Tests complete"