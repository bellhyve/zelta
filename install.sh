#!/bin/sh
#
# Zelta Installer
#
# Note that this installer will clobber /usr/local/share/zelta, /usr/local/bin/zelta,
# and examples, but not other existing files.

if [ "$(id -u)" -eq 0 ]; then
	: ${ZELTA_BIN:="/usr/local/bin"}
	: ${ZELTA_SHARE:="/usr/local/share/zelta"}
	: ${ZELTA_ETC:="/usr/local/etc/zelta"}
	: ${ZELTA_DOC:="/usr/local/man"}
elif [ -z "$ZELTA_BIN" ] || [ -z "$ZELTA_SHARE" ] || [ -z "$ZELTA_ETC" ] || [ -z "$ZELTA_DOC" ]; then
	: ${ZELTA_BIN:="$HOME/bin"}
	: ${ZELTA_SHARE:="$HOME/.local/share/zelta"}
	: ${ZELTA_ETC:="$HOME/.config/zelta"}
	: ${ZELTA_DOC:="$ZELTA_SHARE/doc"}
	echo To install Zelta for this user account:
	echo
	echo 1. Set the following environment variables in your startup script
	echo    or export them with your desired values:
	echo
	echo export ZELTA_BIN=\"$ZELTA_BIN\"
	echo export ZELTA_SHARE=\"$ZELTA_SHARE\"
	echo export ZELTA_ETC=\"$ZELTA_ETC\"
	echo export ZELTA_DOC=\"$ZELTA_DOC\"
	echo
	echo 2. Ensure that \"$ZELTA_BIN\" is in PATH environment variable.
	echo 
	echo Note: If you prefer a global installation, cancel this installation
	echo and rerun this command as root, e.g. \`sudo install.sh\`.
	echo
	echo Proceed with installation?
	echo
	echo Press Control-C to stop or Return to install using the above paths.
	read _wait
fi

: ${ZELTA_CONF:="$ZELTA_ETC/zelta.conf"}
: ${ZELTA_ENV:="$ZELTA_ETC/zelta.env"}
ZELTA="$ZELTA_BIN/zelta"

copy_file() {
	if [ -z "$3" ]; then
		ZELTA_MODE="644"
	else
		ZELTA_MODE="$3"
	fi
	if [ ! -f "$2" ] || [ "$1" -nt "$2" ]; then
		echo "installing: $1 -> $2"
		cp "$1" "$2"
		chmod "$ZELTA_MODE" "$2"
	fi
}

mkdir -p "$ZELTA_BIN" "$ZELTA_SHARE" "$ZELTA_ETC" || {
    echo "Error: Failed to create directories"
    exit 1
}

copy_file bin/zelta "$ZELTA" 755
for file in share/zelta/zelta-*; do
    copy_file "$file" "${ZELTA_SHARE}/${file##*/}"
done

if [ -n "$ZELTA_DOC" ]; then
	for section in 7 8; do
		mandir="${ZELTA_DOC}/man${section}"
		mkdir -p "$mandir"
		for file in doc/*.${section}; do
			copy_file "$file" "$mandir/${file##*/}"
		done
	done
fi

# Environment and default overrides
copy_file zelta.env "${ZELTA_ENV}.example"
if [ ! -s "$ZELTA_ENV" ]; then
	copy_file zelta.env "$ZELTA_ENV"
fi

# Example zelta policy
copy_file zelta.conf "${ZELTA_CONF}.example"
if [ ! -s "$ZELTA_CONF" ]; then
	copy_file zelta.conf "$ZELTA_CONF"
fi

if ! command -v zelta >/dev/null 2>&1; then
	echo
	echo "Warning: 'zelta' not found in PATH."
	echo "Add this to your shell startup file (~/.zshrc, ~/.profile, etc.):"
	echo "    export PATH=\"\$PATH:$ZELTA_BIN\""
fi
