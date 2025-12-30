#!/bin/sh
SRCTOP='apool'
TGTTOP='bpool'
SRCTREE="$SRCTOP/treetop"
TGTTREE="$TGTTOP/backups/treetop"

# Add deterministic data based on snapshot name
etch () {
	zfs list -Hro name -t filesystem $SRCTREE | tr '\n' '\0' | xargs -0 -I% -n1 \
		dd if=/dev/random of='/%/file' bs=64k count=1 > /dev/null 2>&1
	zfs list -Hro name -t volume $SRCTREE | tr '\n' '\0' | xargs -0 -I% -n1 \
		dd if=/dev/random of='/dev/zvol/%' bs=64k count=1 > /dev/null 2>&1
	zfs snapshot -r "$SRCTREE"@snap$1
}

set -x
# Clean house
zfs destroy -vR "$SRCTOP"
zfs destroy -vR "$TGTTOP"

# Create the setup tree
TGTSETUP="$TGTTOP/temp"
zelta backup "$SRCTOP" "$TGTSETUP"/sub1
zelta backup "$SRCTOP" "$TGTSETUP"/sub2/orphan
zelta backup "$SRCTOP" "${TGTSETUP}/sub3/space name"
zfs create -vsV 16G -o volmode=dev $TGTSETUP'/vol1'
