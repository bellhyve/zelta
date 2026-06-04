#!/usr/bin/env bash

TEST_DEF=040_zelta_tests.yml
PROD_SPEC_DIR=spec/0100_standard
./generate_test.sh $TEST_DEF $PROD_SPEC_DIR tag=initialize,standard:22,standard:30