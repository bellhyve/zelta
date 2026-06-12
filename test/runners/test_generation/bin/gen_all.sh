#!/usr/bin/env bash

REPO_ROOT=$(git rev-parse --show-toplevel)
TEST_GEN_DIR="${REPO_ROOT}/test/runners/test_generation"

TEST_DEFS="${TEST_GEN_DIR}/config/test_defs"
RUBY_DIR="${TEST_GEN_DIR}/lib/ruby"
TEST_YML="${TEST_DEFS}/040_zelta_tests.yml"

cd "$REPO_ROOT" || { echo "cannot cd to repo root $REPO_ROOT"; exit 1; }
SPEC_SUBDIR=0100_standard
PROD_SPEC_DIR="${REPO_ROOT}/test/spec/${SPEC_SUBDIR}"
SHELLSPEC_CLEANUP=--setup="shellspec --tag=testgen-destroy"
SHELLSPEC_SETUP=--setup="shellspec --tag=install,initialize,standard:22,standard:30"
VERIFIED_DIR="--verified-dir=$PROD_SPEC_DIR"


shopt -s nullglob
for path in ${TEST_DEFS}/${SPEC_SUBDIR}/*.yml; do
    # printf 'generating test file: %s\n' "$f"
    #for path in .../test_defs/0100_standard/*.yml; do
    printf 'SETUP: %s\n' "$SHELLSPEC_SETUP"
    
    ruby "$RUBY_DIR/run_test_generator.rb" "$VERIFIED_DIR" "$SHELLSPEC_CLEANUP" "$SHELLSPEC_SETUP" "$path" \
	|| exit $?

    f=${path##*/}                       # basename:  040_zelta_tests.yml
    num=${f%%_*}                        # prefix:    040
    n=${num#"${num%%[!0]*}"}            # strip 0s:  40
    [ -n "$n" ] || n=0                  # all-zeros guard: 000 -> 0
    printf '%s\n' "$n"
    SHELLSPEC_SETUP="${SHELLSPEC_SETUP},standard:$n"
done


