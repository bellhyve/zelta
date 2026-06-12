# Modify this file to configure your test pools, datasets and endpoints

# pools
export SANDBOX_ZELTA_SRC_POOL=apool
export SANDBOX_ZELTA_TGT_POOL=bpool

# datasets
export SANDBOX_ZELTA_SRC_DS=apool/treetop
export SANDBOX_ZELTA_TGT_DS=bpool/backups

# remotes setup

# always unset the current remotes first, then override as desired below
unset SANDBOX_ZELTA_SRC_REMOTE
unset SANDBOX_ZELTA_TGT_REMOTE

# * leave these undefined if you're running locally
# * the endpoints are defined automatically and are REMOTE + DS
# Examples: uncomment and customize these if you want to run against remotes.
#export SANDBOX_ZELTA_SRC_REMOTE=user@ubuntu-host  # e.g. Ubuntu source
#export SANDBOX_ZELTA_TGT_REMOTE=user@ubuntu-host  # e.g. Ubuntu remote
#export SANDBOX_ZELTA_SRC_REMOTE=user@freebsd-host # e.g. FreeBSD source
#export SANDBOX_ZELTA_TGT_REMOTE=user@freebsd-host # e.g. FreeBSD remote

# standardize zelta sandbox install location
export SANDBOX_ZELTA_TMP_SUFFIX=$LOGNAME

# to enable test/spec/1000_test_gen/010_testgen_cleanup_spec.sh
export TESTGEN_ZELTA_DESTRUCTIVE=1
