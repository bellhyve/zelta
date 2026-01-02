#!/bin/sh

cat <<EOF
=== Zelta Test One Time setup ===

This scripts adds an entry to sudoers to facilitate sudo without passwords for
a restricted set of root user commands that are needed to initialize the test environment

**
** This script should only be used on test and development machines.
**

NOTE: This test suite requires temporary root access for:
      • Creating ZFS test datasets (Linux mount restrictions)
      • Setting up test pools with proper permissions

      The actual backup tests run with normal user privileges via ZFS delegation.
      You'll be prompted for your password for the setup steps.

EOF

spec/bin/one_time_setup/setup_sudoers.sh

