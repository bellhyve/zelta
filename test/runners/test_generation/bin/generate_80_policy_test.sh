#!/usr/bin/env bash

TEST_DEF=080_zelta_policy_test.yml
PROD_SPEC_DIR=spec/0100_standard
./generate_test.sh $TEST_DEF $PROD_SPEC_DIR tag=initialize,standard:22,standard:30,standard:40,standard:50,standard:60,standard:70