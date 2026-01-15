# Snap tree types, these correspond to different types of tests
export STANDARD_TREE=standard
export DIVERGENT_TREE=divergent
export ENCRYPTED_TREE=encrypted

# Running modes
export RUN_REMOTELY=remote
export RUN_LOCALLY=local

# we use a a/b pool naming convention, were a is the starting point
# and b is used for backups or perturbations to a
export SRC_POOL="apool"
export TGT_POOL="bpool"

# zfs pool creation strategy types
export FILE_IMG_POOL=1

# On Ubuntu we use a loop device backed by a file
export LOOP_DEV_POOL=2

# On FreeBSD we use a memory disk backed by a file
export MEMORY_DISK_POOL=3

export TREETOP_DSN='treetop'
export BACKUPS_DSN='backups'

# zelta version for pool names will include the remote
export SOURCE="${ZELTA_SRC_POOL}/${TREETOP_DSN}"
export TARGET="${ZELTA_TGT_POOL}/${BACKUPS_DSN}/${TREETOP_DSN}"

# zfs versions for pool names do not include th remote
export SRC_TREE="$SRC_POOL/$TREETOP_DSN"
export TGT_TREE="$TGT_POOL/$BACKUPS_DSN/$TREETOP_DSN"
