#!/bin/sh
set -e
curdir=$(pwd)
echo "current dir is {$curdir}"

export SRC_SVR="dever@fzfsdev"
export TGT_SVR="dever@fzfsdev"

# NOTE: see remote_test_setup for remote tree setup

echo "Running zelta tests..."
OPTIONS="${OPTIONS:-}"
#shellspec -f d $OPTIONS ./spec/bin/standard_test/standard_test_spec.sh
shellspec -f d $OPTIONS spec/bin/standard_test/standard_test_spec.sh:@1
shellspec -f d $OPTIONS spec/bin/standard_test/standard_test_spec.sh:@2
shellspec -f d $OPTIONS spec/bin/standard_test/standard_test_spec.sh:@3


