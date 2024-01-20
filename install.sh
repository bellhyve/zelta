#!/bin/sh

: ${ZELTA_BIN:="/usr/local/bin"}
: ${ZELTA_SHARE:="/usr/local/share/zelta"}
: ${ZELTA_ETC:="/usr/local/etc/zelta"}

mkdir -vp "$ZELTA_BIN" "$ZELTA_SHARE" "$ZELTA_ETC"
install -vCm 755 bin/zelta "$ZELTA_BIN"
install -vCm 755 share/zelta/*.awk "$ZELTA_SHARE"

# Optional synonyms for "zelta match" and "zelta sync"
[ -e "$ZELTA_BIN/zmatch" ] || cp -vP bin/zmatch "$ZELTA_BIN"
[ -e "$ZELTA_BIN/zpull" ] || cp -vP bin/zpull "$ZELTA_BIN"
[ -e "$ZELTA_BIN/zsync" ] || cp -vP bin/zsync "$ZELTA_BIN"

# Environment and default overrides
if [ ! -s $ZELTA_ETC/zelta.env ]; then
	install -vm 644 zelta.env "$ZELTA_ETC"
	[ -x /usr/bin/time ] || echo 'TIME_COMMAND="zelta time"' tee -a "$ZELTA_ENV"
fi

# Example zelta policy
if [ ! -s $ZELTA_ETC/zelta.conf ]; then
	install -vm 644 zelta.conf "$ZELTA_ETC"
fi
