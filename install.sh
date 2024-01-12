#!/bin/sh
set -x
mkdir -vp /usr/local/bin /usr/local/share/zelta
install -vm 755 bin/zelta /usr/local/bin
cp -vP bin/zmatch bin/zsync bin/zpull /usr/local/bin/
install -vm 755 share/zelta/*.awk /usr/local/share/zelta
