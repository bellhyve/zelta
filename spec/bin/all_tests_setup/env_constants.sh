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
export LOOP_DEV_POOL=2
