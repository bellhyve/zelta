#!/bin/sh

usage_zelta() {
cat << EOF
usage: zelta command args ...
where 'command' is one of the following:

	version

	match [-Hp] [-d max] [-o field[,...]] source-endpoint target-endpoint

	backup [-bcdDeeFhhLMpuVw] [-iIjnpqRtTv]
	       [initiator] source-endpoint target-endpoint

	sync [bcdDeeFhhLMpuVw] [-iIjnpqRtTv]
	     [initiator] source-endpoint target-endpoint

	clone [-d max] source-dataset target-dataset

	policy [backup-options] [site|host|dataset] ...

Each endpoint is of the form: [user@][host:]dataset

Each dataset is of the form: pool/[dataset/]*dataset[@name]

For further help on a command or topic, run: zelta help [<topic>]
EOF
}

runman() {
	SECTION=8
	if [ ! -s "$ZELTA_DOC" ] ; then
		man "$ZELTA_DOC/$1.$SECTION"
	else
		man $SECTION $1
	fi
}

# Add "man" if available.
case $1 in
	usage|help) usage_zelta ;;
	backup|sync|clone|replicate) runman zelta-backup ;;
	match) runman zelta-match ;;
	policy) runman zelta-policy ;;
	*)	[ -n "$1" ] && echo unrecognized command \'$1\' >>/dev/null ;
		usage_zelta ;;
esac
