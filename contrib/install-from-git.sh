#!/bin/sh
# Zelta One-Shot Installer
# Downloads latest Zelta from GitHub and runs install.sh
#
# Usage: curl -fsSL https://raw.githubusercontent.com/bell-tower/zelta/main/contrib/install-from-git.sh | sh
# Or specify branch: curl ... | sh -s -- --branch=develop

set -e

REPO="https://github.com/bell-tower/zelta.git"
# Parse branch argument: supports 'main', '--branch=main', or '-b=main'
BRANCH="main"
while [ $# -gt 0 ]; do
	case "$1" in
		--branch=*|-b=*) 
			BRANCH="${1#*=}" 
			shift
			;;
		*)
			break
			;;
	esac
done
TMPDIR="${TMPDIR:-/tmp}"
WORKDIR="$TMPDIR/zelta-install-$$"

# Detect git
if ! command -v git >/dev/null 2>&1; then
    echo "Error: git is required but not found"
    exit 1
fi

# Clone to temp location
echo "Downloading Zelta from GitHub..."
git clone --depth=1 --branch="$BRANCH" "$REPO" "$WORKDIR" || {
    echo "Error: Failed to clone repository"
    exit 1
}

cd "$WORKDIR"

# Verify we got a real repo
if [ ! -f "install.sh" ] || [ ! -d ".git" ]; then
    echo "Error: Downloaded files appear incomplete"
    rm -rf "$WORKDIR"
    exit 1
fi

# Preserve commit timestamps to avoid unnecessary reinstallation
_commit_ts=$(git log -1 --format=%ct 2>/dev/null) || _commit_ts=""
if [ -n "$_commit_ts" ]; then
	# Convert Unix timestamp to touch -t format (YYYYMMDDHHMM.SS)
	# Try BSD date (-r seconds) first, then GNU date (-d @seconds)
	_touch_ts=$(date -u -r "$_commit_ts" "+%Y%m%d%H%M.%S" 2>/dev/null || \
	            date -u -d "@$_commit_ts" "+%Y%m%d%H%M.%S" 2>/dev/null || \
	            echo "")
	if [ -n "$_touch_ts" ]; then
		find . -type f -exec touch -t "$_touch_ts" {} +
	fi
fi

# Show what we're installing
echo
echo "Installing Zelta from commit: $(git rev-parse --short HEAD)"
echo

# Run the real installer (suppress its user guidance)
ZELTA_QUIET=1 sh install.sh "$@"
_exit=$?

# Post-installation guidance for non-root users
if [ "$(id -u)" -ne 0 ] && [ -z "$ZELTA_QUIET" ]; then
	_installed_bin="${ZELTA_BIN:-$HOME/bin}"
	_installed_zelta="$_installed_bin/zelta"
	_existing_zelta=$(command -v zelta 2>/dev/null || echo "")
	if [ "$_existing_zelta" = "$_installed_zelta" ]; then
		_action=""
	else
		_action=" - ACTION REQUIRED"
	fi

	echo
	echo "=========================================================="
	echo "INSTALLATION COMPLETE$_action"
	echo "=========================================================="
	echo
	echo "Zelta has been installed to user directories."
	if [ "$_existing_zelta" = "$_installed_zelta" ]; then
		echo "The installed zelta is available in PATH. Keep $_installed_bin in PATH to continue using it."
	else
		echo "To make zelta available in future shell sessions,"
		echo "add the following to your shell startup file"
		echo "(~/.bashrc, ~/.zshrc, ~/.profile, etc.):"
		echo
		echo "    # Zelta configuration"
		echo "    export ZELTA_BIN=\"$_installed_bin\""
		echo "    export PATH=\"\$ZELTA_BIN:\$PATH\""
	fi
	echo
	echo "ZELTA_SHARE, ZELTA_ETC, and ZELTA_DOC will be detected automatically."
	echo "Run '$_installed_zelta version' to use this install immediately."
	echo "=========================================================="
	echo
fi

# Cleanup
cd /
rm -rf "$WORKDIR"

exit $_exit
