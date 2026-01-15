#!/bin/sh

rm -fr "${TEST_INSTALL}"
mkdir -p "${TEST_INSTALL}"
mkdir -p "$ZELTA_MAN8"
# After setting the needed environment variables we
# can use the standard install script
. ./install.sh
