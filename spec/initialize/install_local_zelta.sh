#!/bin/sh


rm -fr "${TEST_INSTALL}"
mkdir -p "${TEST_INSTALL}"

# After setting the needed environment variables we
# can use the standard install script
. ./install.sh
