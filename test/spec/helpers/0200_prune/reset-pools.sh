#!/usr/bin/env sh
# reset-fixture.sh — tear down the snap-maker fixture: destroy the pools,
# remove the image files, and restore time sync. Idempotent and safe to run
# repeatedly while iterating historic_snapshot_maker.sh.
#
# Run as root on the Linux build box (CachyOS / Ubuntu).
#
# Honours the same env overrides as the maker, so keep them consistent:
#   APOOL BPOOL APOOL_IMG BPOOL_IMG

: "${APOOL:=apool}"
: "${BPOOL:=bpool}"
: "${APOOL_IMG:=/tmp/${APOOL}.img}"
: "${BPOOL_IMG:=/tmp/${BPOOL}.img}"

# 1 = destroy a configured pool even when its vdev does NOT match the expected
#     image (i.e. it looks like a real, same-named pool). Use with care.
: "${FORCE:=0}"
# 1 = re-enable time sync. Fixes a clock left stranded in the past if the maker
#     was killed (e.g. SIGKILL) before its restore-clock trap could run.
#: "${RESTORE_NTP:=1}"

log()  { printf '%s  %s\n' "$(date '+%H:%M:%S')" "$*"; }
warn() { printf '%s  WARN: %s\n' "$(date '+%H:%M:%S')" "$*" >&2; }
die()  { printf '%s  FATAL: %s\n' "$(date '+%H:%M:%S')" "$*" >&2; exit 1; }


validate_environment() {
    #[ "$(id -u)" -eq 0 ] || die "must run as root"
    command -v zpool >/dev/null 2>&1 || die "zpool not found"
}

# Destroy one pool if imported, with a vdev-path safety check so a real
# same-named pool isn't clobbered. No-op if the pool isn't imported.
teardown_pool() {
	_pool=$1; _img=$2
	if ! src_exec zpool list "$_pool" >/dev/null 2>&1; then
		log "$_pool not imported (nothing to destroy)"
		return 0
	fi
	if src_exec zpool status -P "$_pool" 2>/dev/null | grep -qF -- "$_img"; then
		log "destroying $_pool (vdev: $_img)"
		src_exec zpool destroy -f "$_pool" || src_exec zpool export "$_pool" \
			|| warn "could not destroy or export $_pool"
	elif [ "$FORCE" -eq 1 ]; then
		warn "$_pool vdev does not match $_img; FORCE=1 -> destroying anyway"
		src_exec zpool destroy -f "$_pool" || src_exec zpool export "$_pool" \
			|| warn "could not destroy or export $_pool"
	else
		warn "$_pool is imported but its vdev is not $_img; refusing (set FORCE=1 to override)"
	fi
}

remove_image() {
	_img=$1
	if [ -e "$_img" ]; then
		rm -f "$_img" && log "removed image $_img" || warn "could not remove $_img"
	else
		log "image $_img absent (nothing to remove)"
	fi
}

teardown_pools() {
    #set -x
    validate_environment
    
    # bpool first (it carries the mounted datasets), then apool.
    teardown_pool "$BPOOL" "$BPOOL_IMG"
    teardown_pool "$APOOL" "$APOOL_IMG"
    remove_image  "$BPOOL_IMG"
    remove_image  "$APOOL_IMG"

    # if [ "$RESTORE_NTP" -eq 1 ] && command -v timedatectl >/dev/null 2>&1; then
    # 	timedatectl set-ntp true >/dev/null 2>&1 \
    # 	    && log "time sync re-enabled" \
    # 		|| warn "could not re-enable time sync (check chrony/ntpd manually)"
    # fi

    log "reset complete."
    #set +x
}
