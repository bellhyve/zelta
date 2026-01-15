#!/bin/sh

. spec/bin/divergent_test/divergent_test_env.sh

# Add deterministic data based on snapshot name
etch () {
	zfs list -Hro name -t filesystem $SRC_TREE | tr '\n' '\0' | xargs -0 -I% -n1 \
		dd if=/dev/random of='/%/file' bs=64k count=1 > /dev/null 2>&1
	zfs list -Hro name -t volume $SRC_TREE | tr '\n' '\0' | xargs -0 -I% -n1 \
		dd if=/dev/random of='/dev/zvol/%' bs=64k count=1 > /dev/null 2>&1
	zfs snapshot -r "$SRC_TREE"@snap$1
}

set -x
# Clean house
zfs destroy -vR "$SRC_POOL"
zfs destroy -vR "$TGT_POOL"

# Create the setup tree
zelta backup "$SRC_POOL" "$TGT_SETUP"/sub1
zelta backup "$SRC_POOL" "$TGT_SETUP"/sub2/orphan
zelta backup "$SRC_POOL" "${TGT_SETUP}/sub3/space name"
zfs create -vsV 16G -o volmode=dev $TGT_SETUP'/vol1'
# TO-DO: Add encrypted dataset

# Sync the temp tree to $SRC_TREE
zelta snapshot "$TGT_SETUP"@set
zelta revert --snap-name "go" "$TGT_SETUP"
zelta backup --snap-name "one" "$TGT_SETUP" "$SRC_TREE"
zelta backup --no-snapshot "$SRC_TREE" "$TGT_TREE"
# TO-DO: Sync with exclude pattern


# Riddle source with special cases

# A child with no snapshot on the source
zfs create "$SRC_TREE"/sub1/child
# A child with no snapshot on the target
zfs create -u "$TGT_TREE"/sub1/kid

# A written target
#zfs set readonly=off "$TGT_TREE"/sub1
#zfs mount "$TGT_TREE"
#zfs mount "$TGT_TREE"/sub1
#touch /"$TGT_TREE"/sub1/data.file

# An orphan
zfs destroy "$SRC_TREE"/sub2@one

# A diverged target
zfs snapshot "$TGT_TREE/sub3/space name@blocker"

# An unsyncable dataset
zfs destroy "$TGT_TREE"/vol1@go

set +x

#dd if=/dev/urandom of=/tmp/zelta-test-key bs=1m count=512

#zfs create -vp $SRC_TREE/'minus/two/one/0/lift off'
#zfs create -vp $SRC_TREE/'minus/two/one/0/lift off'
#for num in `jot 2`; do
#	etch $num
#done
#etch 1; etch 2; etch 3

#etch 8
#zelta sync "$SRC_TREE" "$TGT_TREE"
#zelta match "$SRC_TREE" "$TGT_TREE"