#!/usr/bin/env sh

if [ -z "$SHELLSPEC_HELPERDIR" ]; then
  REPO_ROOT=${REPO_ROOT:=$(git rev-parse --show-toplevel)}
  SHELLSPEC_HELPERDIR="$REPO_ROOT/test/spec/helpers"
fi

. "${SHELLSPEC_HELPERDIR}/0200_prune/reset-pools.sh"

teardown_pools
0