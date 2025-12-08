#!/bin/sh
apool=apool
bpool=bpool
src_ep='root@host07.bts'
tgt_ep='root@host07.bts'
src="$tgt_ep:$apool/treetop"
tgt="$tgt_ep:$bpool/bleetop"
which zelta
echo $ZELTA_SHARE
export ZELTA_LOG_LEVEL=4
export AWK="gawk"
clear

{

set -x
sleep 1

zelta backup "$src" "$tgt"
zelta rotate "$src" "$tgt"
zelta revert "$src"
zelta rotate "$src" "$tgt"

#zelta backup --snapshot-always "$src" "$tgt"
#zelta backup --snapshot-always "$src" "$tgt"
#zelta match "$src" "$tgt"
#zelta rotate "$src" "$tgt"
#zelta match "$src" "$tgt"
##zelta revert "$src"
#zelta rotate "$src" "$tgt"
#zelta match "$src" "$tgt"

}
