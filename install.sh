#!/bin/sh

if [ root = "$USER" ]; then
	: ${ZELTA_BIN:="/usr/local/bin"}
	: ${ZELTA_SHARE:="/usr/local/share/zelta"}
	: ${ZELTA_ETC:="/usr/local/etc/zelta"}
elif [ -z "$ZELTA_BIN$ZELTA_SHARE$ZELTA_ETC" ]; then
	: ${ZELTA_BIN:="$HOME/bin"}
	: ${ZELTA_SHARE:="$HOME/.local/share/zelta"}
	: ${ZELTA_ETC:="$HOME/.config/zelta"}
	echo Installing Zelta as an unprivilaged user. To ensure the per-user setup of
	echo Zelta is being used, please export the following environment variables in
	echo your shell\'s startup scripts:
	echo
	echo export ZELTA_BIN=\"$ZELTA_BIN\"
	echo export ZELTA_SHARE=\"$ZELTA_SHARE\"
	echo export ZELTA_ETC=\"$ZELTA_ETC\"
	echo 
	echo You may also set these variables as desired and rerun this command.
	echo -n Press Control-C to break or Return to install; read whatever
fi

: ${ZELTA_CONF:="$ZELTA_ETC/zelta.conf"}
: ${ZELTA_ENV:="$ZELTA_ETC/zelta.env"}

mkdir -vp "$ZELTA_BIN" "$ZELTA_SHARE" "$ZELTA_ETC"
install -vCm 755 bin/zelta "$ZELTA_BIN"
install -vCm 755 share/zelta/*.awk "$ZELTA_SHARE"

# Optional synonyms for "zelta match" and "zelta sync"
[ -e "$ZELTA_BIN/zmatch" ] || cp -vP bin/zmatch "$ZELTA_BIN"
[ -e "$ZELTA_BIN/zpull" ] || cp -vP bin/zpull "$ZELTA_BIN"
[ -e "$ZELTA_BIN/zsync" ] || cp -vP bin/zsync "$ZELTA_BIN"

# Environment and default overrides
if [ ! -s $ZELTA_ENV ]; then
	install -vm 644 zelta.env "$ZELTA_ENV"
	[ -x /usr/bin/time ] || echo 'TIME_COMMAND="zelta time"' >> "$ZELTA_ENV"
fi

# Example zelta policy
if [ ! -s $ZELTA_CONF ]; then
	install -vm 644 zelta.conf "$ZELTA_CONF"
fi
