#!/bin/sh
. ./spec/initialize/test_env.sh
sudo zpool destroy -f $SRC_POOL
sudo zpool destroy -f $TGT_POOL
