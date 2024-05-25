#!/bin/sh
#
# Zelta Installer
#
# Note that this will clobber /usr/local/share/zelta, /usr/local/bin/zelta, and
# examples, but not other existing files. Keep this in mind if you intend to
# directly modify the installed copies.

if [ root = "$USER" ]; then
	: ${ZELTA_BIN:="/usr/local/bin"}
	: ${ZELTA_SHARE:="/usr/local/share/zelta"}
	: ${ZELTA_ETC:="/usr/local/etc/zelta"}
	: ${ZELTA_MAN8:="/usr/local/share/man/man8"}
	if [ ! -d "$ZELTA_MAN8" ] ; then
		ZELTA_MAN="/usr/share/man/man8"
	fi
elif [ -z "$ZELTA_BIN$ZELTA_SHARE$ZELTA_ETC$ZELTA_DOC" ]; then
	: ${ZELTA_BIN:="$HOME/bin"}
	: ${ZELTA_SHARE:="$HOME/.local/share/zelta"}
	: ${ZELTA_ETC:="$HOME/.config/zelta"}
	: ${ZELTA_DOC:="$ZELTA_SHARE/doc"}
	echo Installing Zelta as an unprivilaged user. To ensure the per-user setup of
	echo Zelta is being used, please export the following environment variables in
	echo your shell\'s startup scripts:
	echo
	echo export ZELTA_BIN=\"$ZELTA_BIN\"
	echo export ZELTA_SHARE=\"$ZELTA_SHARE\"
	echo export ZELTA_ETC=\"$ZELTA_ETC\"
	echo export ZELTA_MAN=\"$ZELTA_DOC\"
	echo 
	echo You may also set these variables as desired and rerun this command.
	echo Press Control-C to break or Return to install; read whatever
fi

: ${ZELTA_CONF:="$ZELTA_ETC/zelta.conf"}
: ${ZELTA_ENV:="$ZELTA_ETC/zelta.env"}
ZELTA="$ZELTA_BIN/zelta"

copy_file() {
	if [ -z "$3" ]; then
		ZELTA_MODE="755"
	else
		ZELTA_MODE="$3"
	fi
	if [ ! -f "$2" ] || [ "$1" -nt "$2" ]; then
		echo "installing: $1 -> $2"
		cp "$1" "$2"
		chmod "$ZELTA_MODE" "$2"
	fi
}

link_to_zelta() {
	if [ ! -e "$ZELTA_BIN/$1" ]; then
		echo "symlinking: $ZELTA -> $1"
		ln -s $ZELTA "$ZELTA_BIN/$1"
	fi
}


mkdir -p "$ZELTA_BIN" "$ZELTA_SHARE" "$ZELTA_ETC" "$ZELTA_DOC"
copy_file bin/zelta "$ZELTA"
find share/zelta -name '*.awk' -o -name '*.sh' | while read -r file; do
    copy_file "$file" "${ZELTA_SHARE}/$(basename "$file")"
done

if [ -x "$ZELTA_MAN8" ] ; then
	find doc -name '*.8' | while read -r file; do
		echo emm
	    copy_file "$file" "${ZELTA_MAN}/$(basename "$file")"
	done
fi

## Old Aliases:
# link_to_zelta zmatch
# link_to_zelta zpull
# link_to_zelta zp

# Environment and default overrides
copy_file zelta.env "${ZELTA_ENV}.example"
if [ ! -s "$ZELTA_ENV" ]; then
	copy_file zelta.env "$ZELTA_ENV"
	[ -x /usr/bin/time ] || echo 'TIME_COMMAND="zelta time"' >> "$ZELTA_ENV"
fi

# Example zelta policy
copy_file zelta.conf "${ZELTA_CONF}.example" "644"
if [ ! -s "$ZELTA_CONF" ]; then
	copy_file zelta.conf "$ZELTA_CONF" "644"
fi

# Add doc if requested
if [ "$ZELTA_DOC" ]; then
	mkdir -p "$ZELTA_DOC"
	find doc/ -type f | while read -r file; do
	    copy_file "$file" "${ZELTA_DOC}/$(basename "$file")"
	done
fi
