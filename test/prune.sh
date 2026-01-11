#!/bin/sh
DSNAME="$1"
KEEP_MIN=10
KEEP_DAYS=90
[ -z "$1" ] && exit
KEEP_MIN=$(($(zfs list -Hroname "$DSNAME"|wc -l)*KEEP_MIN))
KEEP_DAYS="$(($(date +%s)-60*60*24*KEEP_DAYS))"

zfs list -Hprtsnap -oname,creation -screation "$DSNAME" | awk -v min=$KEEP_MIN -v days=$KEEP_DAYS '
{
	if ($2<days) {
		x[++y]=$1
		if (x[y-min])
			print x[y-min]
	}
}'
