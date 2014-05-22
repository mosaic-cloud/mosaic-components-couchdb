#!/bin/bash

set -e -E -u -o pipefail -o noclobber -o noglob -o braceexpand || exit 1
trap 'printf "[ee] failed: %s\n" "${BASH_COMMAND}" >&2' ERR || exit 1

test "${#}" -eq 0

cd -- "$( dirname -- "$( readlink -e -- "${0}" )" )"
test -d ./.generated

cp -T ./repositories/ejson/ejson.app.in ./.generated/ejson.app

gcc -shared -o ./.generated/ejson.so \
		-I ./.generated \
		-I ./repositories/ejson \
		-I ./repositories/ejson/yajl \
		-I "${pallur_pkg_erlang:-/usr/lib/erlang}/usr/include" \
		-L "${pallur_pkg_erlang:-/usr/lib/erlang}/usr/lib" \
		${pallur_CFLAGS:-} ${pallur_LDFLAGS:-} \
		./repositories/ejson/{ejson.c,encode.c,decode.c} \
		./repositories/ejson/yajl/{yajl.c,yajl_alloc.c,yajl_buf.c,yajl_encode.c,yajl_gen.c,yajl_lex.c,yajl_parser.c} \
		${pallur_LIBS:-}

exit 0
