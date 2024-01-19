#!/bin/sh
: ${ZELTA_SHARE:="/usr/local/share/zelta"}
: ${ZELTA_ETC:="/usr/local/etc/zelta"}
: ${ZELTA_ENV:="$ZELTA_ETC/zelta.env"}
: ${AWK:="`which awk`"}
mkdir -vp /usr/local/bin "$ZELTA_SHARE" "$ZELTA_ETC"
install -vm 755 bin/zelta /usr/local/bin
cp -vP bin/zmatch bin/zsync bin/zpull /usr/local/bin/
install -vm 755 share/zelta/*.awk /usr/local/share/zelta
[ -x /usr/bin/time ] || echo 'TIME_COMMAND="zelta time"' >> $ZELTA_ENV
