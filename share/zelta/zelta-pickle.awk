#!/usr/bin/awk -f
#

function make_ord() { for(n=0;n<256;n++) ord[sprintf("%c",n)] = n }

function pickle_hash(text) {
	text = text ? text : $0
	_prime = 104729;
	_modulo = 1099511627775;
	_ax = 0;
	split(text, _chars, "");
	for (_i=1; _i <= length(text); _i++) {
		_ax = (_ax * _prime + ord[_chars[_i]]) % _modulo;
	};
	return sprintf("%010x", _ax)
}

BEGIN {
	make_ord() 
	ZELTA_CACHE_DIR = ENVIRON["ZELTA_CACHE_DIR"] ? ENVIRON["ZELTA_CACHE_DIR"] : ENVIRON["HOME"]"/.config/zelta/cache/"
	if (ZELTA_CACHE_DIR && (ZELTA_CACHE_DIR~/[^\/]$/)) ZELTA_CACHE_DIR = ZELTA_CACHE_DIR"/"
	print ZELTA_CACHE_DIR pickle_hash(ARGV[1])
}
