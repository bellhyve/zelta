#!/usr/bin/env sh
# restore-fixture.sh — restore test pools from the golden images. Intended as
# the per-test (BeforeEach) setup step: it makes a fresh disposable copy of
# each golden image and imports the pool from THAT copy, so the golden is
# never mutated and every test starts from byte-identical state.
#
# Run as root on the Linux VM.  (The FreeBSD target needs an md(4) variant;
# this is the Linux import path.)
#
# `creation` and snapshot GUIDs are carried by the on-disk metadata and are
# preserved verbatim by copy + import, so the historical dates survive.

# ---- Config (env-overridable; keep in sync with the maker/reset scripts) ----
#: "${GOLDEN_DIR:=/var/lib/zelta-fixtures/golden}"  # read-only truth: <pool>.img
: "${GOLDEN_DIR:=${SHELLSPEC_HELPERDIR}/0200_prune/golden}"  # read-only truth: <pool>.img
: "${WORK_DIR:=/tmp}"                              # disposable working copies
: "${POOLS:=apool bpool}"                          # which pools to restore
: "${VERIFY_DS:=}"                                 # optional dataset to sanity-check
# -----------------------------------------------------------------------------

log()  { printf '%s  %s\n' "$(date '+%H:%M:%S')" "$*"; }
warn() { printf '%s  WARN: %s\n' "$(date '+%H:%M:%S')" "$*" >&2; }
die()  { printf '%s  FATAL: %s\n' "$(date '+%H:%M:%S')" "$*" >&2; exit 1; }


validate_environment() {
    #[ "$(id -u)" -eq 0 ] || die "must run as root"
    command -v zpool >/dev/null 2>&1 || die "zpool not found"

    # Refuse to run if golden and working dirs are the same path: a cp over the
    # golden would corrupt the source of truth.
    _gd=$(cd "$GOLDEN_DIR" 2>/dev/null && pwd) || die "GOLDEN_DIR '$GOLDEN_DIR' does not exist"
    mkdir -p "$WORK_DIR" || die "cannot create WORK_DIR '$WORK_DIR'"
    _wd=$(cd "$WORK_DIR" && pwd)
    [ "$_gd" != "$_wd" ] || die "GOLDEN_DIR and WORK_DIR must differ (refusing to overwrite the golden)"
}

# Tear down a prior import of this pool, but only if its vdev is the working
# copy — never clobber a real same-named pool. Idempotent.
predestroy() {
	_pool=$1; _work=$2
	src_exec zpool list "$_pool" >/dev/null 2>&1 || return 0
	if src_exec zpool status -P "$_pool" 2>/dev/null | grep -qF -- "$_work"; then
		src_exec zpool destroy -f "$_pool" || src_exec zpool export "$_pool" \
			|| die "could not clear prior import of $_pool"
	else
		die "$_pool is already imported on a vdev that is not $_work; refusing"
	fi
}

restore_one() {
	_pool=$1
	_golden=$GOLDEN_DIR/$_pool.img
	_work=$WORK_DIR/$_pool.img
	[ -f "$_golden" ] || die "golden image not found: $_golden"

	predestroy "$_pool" "$_work"
	rm -f "$_work" || die "could not remove stale working image $_work"

	# Sparse copy so the 128m image stays tiny and fast (ms).
	cp --sparse=always "$_golden" "$_work" || die "copy of $_golden -> $_work failed"

	# -f covers the hostid guard when the importing host differs from the
	# host that built the golden. -d scans WORK_DIR for the file vdev.
	src_exec zpool import -d "$WORK_DIR" -f "$_pool" \
		|| die "import of $_pool from $_work failed"

	log "restored $_pool (vdev: $_work)"
}

restore_pools() {
    #set -x
    validate_environment
    
    for _p in $POOLS; do
	restore_one "$_p"
    done

    # Optional cheap sanity check: confirm the historical dataset is present and
    # report its snapshot span, so a silently-empty fixture fails the test setup
    # rather than the assertions.
    if [ -n "$VERIFY_DS" ]; then
	if zfs list "$VERIFY_DS" >/dev/null 2>&1; then
	    _n=$(zfs list -H -t snapshot -o name -r "$VERIFY_DS" | wc -l | tr -d ' ')
	    _oldest=$(zfs list -H -p -t snapshot -o creation -s creation -r "$VERIFY_DS" | head -n1)
	    _newest=$(zfs list -H -p -t snapshot -o creation -s creation -r "$VERIFY_DS" | tail -n1)
	    log "verify: $VERIFY_DS has $_n snapshot(s), creation epochs $_oldest..$_newest"
	    [ "$_n" -gt 0 ] || die "verify: $VERIFY_DS has no snapshots"
	else
	    die "verify: dataset $VERIFY_DS not found after import"
	fi
    fi

    log "restore complete."
    #set +x
}
