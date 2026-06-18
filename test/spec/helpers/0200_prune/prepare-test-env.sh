#!/usr/bin/env sh

if [ -z "$SHELLSPEC_HELPERDIR" ]; then
  REPO_ROOT=${REPO_ROOT:=$(git rev-parse --show-toplevel)}
  SHELLSPEC_HELPERDIR="$REPO_ROOT/test/spec/helpers"
fi



. "${SHELLSPEC_HELPERDIR}/spec_helper.sh"
. "${SHELLSPEC_HELPERDIR}/0200_prune/reset-pools.sh"
. "${SHELLSPEC_HELPERDIR}/0200_prune/restore-pools.sh"

teardown_pools
restore_pools
