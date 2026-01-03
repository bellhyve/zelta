#!/bin/sh
set -e
curdir=$(pwd)
echo "current dir is {$curdir}"

export SRC_SVR="dever@fzfsdev"
export TGT_SVR="dever@fzfsdev"
# TODO: sort out how to get this to work

echo "Step 3/3: Running zelta tests..."
OPTIONS="${OPTIONS:-}"
#shellspec -f d $OPTIONS ./spec/bin/standard_test/standard_test_spec.sh
shellspec -f d $OPTIONS spec/bin/standard_test/standard_test_spec.sh:@1
shellspec -f d $OPTIONS spec/bin/standard_test/standard_test_spec.sh:@2
shellspec -f d $OPTIONS spec/bin/standard_test/standard_test_spec.sh:@3


