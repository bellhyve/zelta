#!/usr/bin/env sh
# historic_labled_snapshot_maker.sh — build a golden ZFS fixture for testing
# the NAME-matching options of `zelta prune` (`--include` / `--exclude`).
#
# This is the labeled sibling of historic_snapshot_maker.sh. It works exactly
# the same way — step the system clock back in time, churn a rotating subset of
# files, then `zelta backup` (snapshot SOURCE + replicate to TARGET in one call
# so the received target snapshots keep the source GUIDs and historical
# `creation`) — with ONE addition: each snapshot is given a GFS retention label
# baked into its name via `zelta backup --snap-name`.
#
# LABELS
#   Iterating oldest -> newest, every backup is tagged with the HIGHEST calendar
#   boundary it crosses since the previous backup:
#       new UTC year   -> yearly
#       else new month -> monthly
#       else new ISO wk -> weekly
#       else           -> daily
#   The boundary is computed in UTC so it matches the UTC timestamp the snapshot
#   name embeds. Names look like:
#       zelta_daily_2026-06-14_20.00.00
#       zelta_weekly_2026-06-08_00.00.00
#       zelta_monthly_2026-06-01_00.00.00
#       zelta_yearly_2026-01-01_00.00.00
#   Result: a realistic spread (few yearly, more monthly/weekly, many daily) so
#   `zelta prune --include daily`, `--exclude monthly`, etc. have real material
#   to match against.
#
#   Default `zelta backup` snapshot name (for reference):
#       --snap-name NAME   Default: $(date -u +zelta_%Y-%m-%d_%H.%M.%S)
#
# Target host:  Ubuntu 24.04.4 LTS  (zfs-2.2.2-0ubuntu9.4)
#
# DETERMINISM
#   prune computes age as (now - creation); `now` is wall-clock at prune time.
#   Dates here are FIXED relative to BASE_NOW. Pin prune's "now" to BASE_NOW
#   (faketime / ShellSpec time mock / a ZELTA_NOW seam) for stable age math.
#
# !! RUN ONLY ON A DISPOSABLE VM !!  This script moves the system clock.

# ---- zelta environment (preserved as provided) -----------------------------
export ZELTA_BIN="/home/dever/bin"
export ZELTA_SHARE="/home/dever/.local/share/zelta"
export ZELTA_ETC="/home/dever/.config/zelta"
export ZELTA_DOC="/home/dever/.local/share/zelta/doc"
PATH="$ZELTA_BIN:$PATH"

# ---- Tunables (overridable from env) ---------------------------------------
: "${APOOL:=apool}"
: "${BPOOL:=bpool}"
: "${APOOL_IMG:=/tmp/${APOOL}.img}"
: "${BPOOL_IMG:=/tmp/${BPOOL}.img}"
: "${POOL_SIZE:=128m}"
: "${COMPAT:=openzfs-2.1-linux}"        # lowest-common-denominator for import

: "${SRC_DS:=apool/treetop}"            # source dataset (churned + snapshotted)
: "${TGT_DS:=bpool/backups}"            # zelta target; data lands here directly
                                        # (1:1 mapping, NOT a nested child).
                                        # Do NOT pre-create it: the first
                                        # `zelta backup` full-send creates it,
                                        # which is what keeps GUIDs matched.
: "${ZELTA:=zelta}"

: "${FILE_COUNT:=5}"                    # files in the dataset
: "${FILE_SIZE:=100K}"
: "${CHANGE_COUNT:=2}"                  # files changed per snapshot (rotating)

: "${BASE_NOW:=2026-06-14 21:00:00}"    # reference "now" for prune age math
: "${FORCE:=0}"                         # 1 = destroy pre-existing pools/images
# ----------------------------------------------------------------------------

REPL_DS="$TGT_DS"                       # received copy lands on TGT_DS itself
SRC_MNT=""                              # resolved in PREPARE

# GFS label state (UTC boundaries seen so far; updated oldest -> newest).
LAST_YEAR=""; LAST_MONTH=""; LAST_WEEK=""; LABEL=""

log()  { printf '%s  %s\n' "$(date '+%H:%M:%S')" "$*"; }
warn() { printf '%s  WARN: %s\n' "$(date '+%H:%M:%S')" "$*" >&2; }
die()  { printf '%s  FATAL: %s\n' "$(date '+%H:%M:%S')" "$*" >&2; exit 1; }

# Oldest first -> clock steps forward each iteration (monotonic creation).
# Epoch arithmetic avoids GNU date's "time + signed number = tz offset" trap.
# Edit these second-offsets to populate the retention buckets you test.
light_snapshot_plan() {
	_base=$(date -d "$BASE_NOW" +%s) || return 1
	_day=86400; _hour=3600
	for _off in \
		"$((90 * _day))" "$((30 * _day))" "$((14 * _day))" "$((7 * _day))" \
		"$((2 * _day))"  "$((1 * _day))"  "$((6 * _hour))" "$((1 * _hour))"; do
		date -d "@$(( _base - _off ))" '+%Y-%m-%d %H:%M:%S'
	done
}


snapshot_plan() {
	_base=$(date -d "$BASE_NOW" +%s) || return 1
	_h=3600; _d=86400
	#_stop=$(( 730 * _d ))             # how far back to go (~2 years)
	_stop=$(( 1095 * _d ))            # how far back to go (~3 years)

	# Walk backward from BASE_NOW, finer cadence recently, coarser further
	# back. Deliberate over-density per band so a GFS --prune-grid has
	# multiple candidates to thin in each day/week/month bucket. Tune the
	# thresholds/steps freely; output is sorted oldest-first.
	_age=0
	while [ "$_age" -le "$_stop" ]; do
		date -d "@$(( _base - _age ))" '+%Y-%m-%d %H:%M:%S'
		if   [ "$_age" -lt $((   7 * _d )) ]; then _step=$((  6 * _h ))   # <=1 week:   every 6h (4/day)
		elif [ "$_age" -lt $((  30 * _d )) ]; then _step=$((  1 * _d ))   # <=1 month:  daily
		elif [ "$_age" -lt $(( 180 * _d )) ]; then _step=$((  3 * _d ))   # <=6 months: every 3d
		else                                       _step=$(( 14 * _d ))   # 6mo-2yr:    every 14d
		fi
		_age=$(( _age + _step ))
	done | sort
}


# Initial file set (real clock; this is the baseline the first snapshot sends).
add_test_files() {
	_i=1
	while [ "$_i" -le "$FILE_COUNT" ]; do
		dd if=/dev/urandom of="$SRC_MNT/file_$_i" bs="$FILE_SIZE" count=1 \
			conv=notrunc status=none || return 1
		_i=$((_i + 1))
	done
	sync
}

# Overwrite CHANGE_COUNT files in place, rotating which ones by iteration so
# changes spread across the dataset over time (realistic incremental deltas).
# conv=notrunc + matching size replaces every block of each touched file.
modify_files() {
	_iter=$1; _k=0
	while [ "$_k" -lt "$CHANGE_COUNT" ]; do
		_idx=$(( (_iter + _k - 1) % FILE_COUNT + 1 ))
		dd if=/dev/urandom of="$SRC_MNT/file_$_idx" bs="$FILE_SIZE" count=1 \
			conv=notrunc status=none || return 1
		log "    changed file_$_idx"
		_k=$((_k + 1))
	done
	sync
}

# GFS label for the CURRENT (already-set) system clock: the highest calendar
# boundary crossed since the previous backup. UTC frame so it matches the UTC
# timestamp the snapshot name embeds. Sets the global LABEL to
# daily|weekly|monthly|yearly and advances the LAST_* boundary state.
#
# NOTE: sets a global rather than echoing on purpose — a `LABEL=$(label_now)`
# call substitution would run in a subshell and lose the LAST_* updates, so
# every snapshot would collapse to a single label.
label_now() {
	_ny=$(date -u +%Y); _nm=$(date -u +%Y-%m); _nw=$(date -u +%G-%V)
	if   [ "$_ny" != "$LAST_YEAR"  ]; then LABEL=yearly
	elif [ "$_nm" != "$LAST_MONTH" ]; then LABEL=monthly
	elif [ "$_nw" != "$LAST_WEEK"  ]; then LABEL=weekly
	else                                   LABEL=daily
	fi
	LAST_YEAR=$_ny; LAST_MONTH=$_nm; LAST_WEEK=$_nw
}

# One real backup: zelta snapshots the source (label + timestamp name from the
# stepped clock) and replicates to the target. First call full-sends and
# CREATES the target dataset; later calls are GUID-matched incrementals.
# The label is baked into the snapshot name via --snap-name so `zelta prune`
# --include/--exclude can match on it. Edit here if your invocation differs.
backup() {
	_label=$1
	"$ZELTA" backup \
		--snap-name "$(date -u +"zelta_${_label}_%Y-%m-%d_%H.%M.%S")" \
		--snapshot "$SRC_DS" "$TGT_DS"
}

# ---- Clock save / restore (monotonic-based; survives offline) ---------------
CLOCK_SAVED=0; REAL_EPOCH=0; MONO_AT_SAVE=0
save_clock() {
	REAL_EPOCH=$(date +%s)
	MONO_AT_SAVE=$(awk '{print int($1)}' /proc/uptime)
	CLOCK_SAVED=1
}
restore_clock() {
	[ "$CLOCK_SAVED" -eq 1 ] || return 0
	_mono_now=$(awk '{print int($1)}' /proc/uptime)
	_real_now=$(( REAL_EPOCH + (_mono_now - MONO_AT_SAVE) ))
	date -s "@$_real_now" >/dev/null 2>&1 || warn "could not restore clock via date -s"
	timedatectl set-ntp true >/dev/null 2>&1 || true
	log "clock restored (~ $(date '+%Y-%m-%d %H:%M:%S'))"
}
disable_timesync() {
	timedatectl set-ntp false >/dev/null 2>&1 \
		|| warn "set-ntp false failed (chrony/ntpd? hypervisor guest-agent?)"
	for _svc in chrony chronyd ntp ntpsec; do
		systemctl stop "$_svc" >/dev/null 2>&1 || true
	done
}

create_pool() {
	_name=$1; _img=$2
	truncate -s "$POOL_SIZE" "$_img" || return 1
	zpool create -f -o compatibility="$COMPAT" \
		-O compression=off -O atime=off "$_name" "$_img" || return 1
}

# ---- PHASE 1: VALIDATE ------------------------------------------------------
[ "$(id -u)" -eq 0 ] || die "must run as root (needs 'date -s' and zpool)"
[ -r /proc/uptime ]  || die "/proc/uptime not readable; cannot safely restore clock"
for _bin in zpool zfs truncate dd awk date; do
	command -v "$_bin" >/dev/null 2>&1 || die "missing required command: $_bin"
done
command -v "$ZELTA" >/dev/null 2>&1 || die "zelta not found on PATH ($ZELTA_BIN)"
[ "$CHANGE_COUNT" -le "$FILE_COUNT" ] || die "CHANGE_COUNT ($CHANGE_COUNT) > FILE_COUNT ($FILE_COUNT)"

# ---- PHASE 2: PREPARE -------------------------------------------------------
for _p in "$BPOOL" "$APOOL"; do
	if zpool list "$_p" >/dev/null 2>&1; then
		[ "$FORCE" -eq 1 ] || die "pool '$_p' already imported; set FORCE=1 to destroy & rebuild"
		log "FORCE: destroying existing pool $_p"
		zpool destroy -f "$_p" || die "could not destroy $_p"
	fi
done
for _f in "$BPOOL_IMG" "$APOOL_IMG"; do
	if [ -e "$_f" ]; then
		[ "$FORCE" -eq 1 ] || die "image '$_f' exists; set FORCE=1 to overwrite"
		rm -f "$_f" || die "could not remove $_f"
	fi
done

log "creating pools (size=$POOL_SIZE, compat=$COMPAT)"
create_pool "$APOOL" "$APOOL_IMG" || die "failed to create $APOOL"
create_pool "$BPOOL" "$BPOOL_IMG" || die "failed to create $BPOOL"

# Source dataset only. The TARGET dataset ($TGT_DS) is intentionally NOT
# created here — zelta's first full send creates it as a received copy, so its
# snapshots inherit the source GUIDs. Pre-creating it is what caused the
# "target diverged" failure.
log "creating source dataset $SRC_DS"
zfs create "$SRC_DS" || die "failed to create $SRC_DS"
zfs allow -e destroy,mount "$SRC_DS"

SRC_MNT=$(zfs get -H -o value mountpoint "$SRC_DS") || die "cannot resolve mountpoint of $SRC_DS"
[ -d "$SRC_MNT" ] || die "mountpoint $SRC_MNT for $SRC_DS does not exist"

log "seeding initial file set ($FILE_COUNT x $FILE_SIZE)"
add_test_files || die "failed to create initial files"

PLAN=$(snapshot_plan) || die "failed to build snapshot plan"
[ -n "$PLAN" ] || die "snapshot plan is empty"

# ---- PHASE 3: EXECUTE (clock-skewed window) --------------------------------
save_clock
disable_timesync
trap 'restore_clock' EXIT INT TERM HUP
log "system time control acquired; building historical labeled backups"

_iter=1
_oldifs=$IFS
IFS='
'
for _clock in $PLAN; do
	IFS=$_oldifs

	date -s "$_clock" >/dev/null 2>&1 || die "failed to set clock to '$_clock'"
	label_now                         # sets $LABEL from the now-stepped clock
	log "=== snapshot $_iter @ $_clock [$LABEL] ==="
	modify_files "$_iter" || die "file modification failed at iter $_iter"
	backup "$LABEL"       || die "zelta backup failed at iter $_iter ($_clock)"

	_iter=$((_iter + 1))
	IFS='
'
done
IFS=$_oldifs

restore_clock
trap - EXIT INT TERM HUP

# ---- PHASE 4: REPORT + VERIFY ----------------------------------------------
log "=== SOURCE snapshots ($SRC_DS) ==="
zfs list -t snapshot -o name,creation,used,refer -r "$SRC_DS" || warn "source listing failed"
log "=== TARGET snapshots ($REPL_DS) ==="
zfs list -t snapshot -o name,creation,used,refer -r "$REPL_DS" || warn "target listing failed"

# Label distribution (source side) — a sanity check that all four buckets got
# populated so --include/--exclude tests have material in each.
log "=== label distribution ($SRC_DS) ==="
for _lbl in daily weekly monthly yearly; do
	_n=$(zfs list -H -t snapshot -o name -r "$SRC_DS" | grep -c "@zelta_${_lbl}_")
	log "  $_lbl: $_n"
done

# A matched fixture: source and target must have equal snapshot counts, the
# same creation span, AND a shared GUID set (the thing zelta actually checks).
_src_n=$(zfs list -H -t snapshot -o name -r "$SRC_DS"  | wc -l | tr -d ' ')
_tgt_n=$(zfs list -H -t snapshot -o name -r "$REPL_DS" | wc -l | tr -d ' ')
_src_span=$(zfs list -Hp -t snapshot -o creation -s creation -r "$SRC_DS"  | sed -n '1p;$p' | tr '\n' '-')
_tgt_span=$(zfs list -Hp -t snapshot -o creation -s creation -r "$REPL_DS" | sed -n '1p;$p' | tr '\n' '-')
_shared=$(
	{ zfs list -H -o guid -t snapshot -r "$SRC_DS"
	  zfs list -H -o guid -t snapshot -r "$REPL_DS"; } | sort | uniq -d | wc -l | tr -d ' '
)
log "verify: source=$_src_n target=$_tgt_n shared_guids=$_shared"
log "verify: src_span=$_src_span tgt_span=$_tgt_span"
[ "$_src_n" = "$_tgt_n" ]       || warn "source/target snapshot counts differ"
[ "$_src_span" = "$_tgt_span" ] || warn "creation spans differ (receive may not have inherited the skewed clock)"
[ "$_shared" = "$_src_n" ]      || warn "not all snapshots share GUIDs (lineage broken -> zelta will see divergence)"

# ---- PHASE 5: EXPORT (leave golden images ready to copy) -------------------
log "exporting pools"
zfs allow -e destroy,mount "$TGT_DS"
zpool export "$BPOOL" || die "export of $BPOOL failed (busy? check mounts under $TGT_DS)"
zpool export "$APOOL" || warn "export of $APOOL failed"

log "done."
log "golden images:  source=$APOOL_IMG  target=$BPOOL_IMG"
log "pin prune's clock to BASE_NOW for deterministic age math: $BASE_NOW"
