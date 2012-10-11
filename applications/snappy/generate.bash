#!/bin/bash

set -e -E -u -o pipefail -o noclobber -o noglob -o braceexpand || exit 1
trap 'printf "[ee] failed: %s\n" "${BASH_COMMAND}" >&2' ERR || exit 1

test "${#}" -eq 0

cd -- "$( dirname -- "$( readlink -e -- "${0}" )" )"

rm -Rf ./.generated
mkdir ./.generated

cp -T ./repositories/snappy/snappy.app.in ./.generated/snappy.app

cp -T ./repositories/snappy/google-snappy/snappy-stubs-public.h.in ./.generated/snappy-stubs-public.h

sed -r \
		-e 's!@SNAPPY_MAJOR@!0!g' \
		-e 's!@SNAPPY_MINOR@!0!g' \
		-e 's!@SNAPPY_PATCHLEVEL@!0!g' \
		-e 's!@ac_cv_have_stdint_h@!HAVE_STDINT_H!g' \
		-e 's!@ac_cv_have_stddef_h@!HAVE_STDDEF_H!g' \
		-i ./.generated/snappy-stubs-public.h

gcc -shared -o ./.generated/snappy_nif.so \
		-I ./.generated \
		-I ./repositories/snappy \
		-I ./repositories/snappy/google-snappy \
		-I "${mosaic_pkg_erlang:-/usr/lib/erlang}/usr/include" \
		-L "${mosaic_pkg_erlang:-/usr/lib/erlang}/usr/lib" \
		${mosaic_CFLAGS:-} ${mosaic_LDFLAGS:-} \
		./repositories/snappy/snappy_nif.cc \
		./repositories/snappy/google-snappy/{snappy-sinksource.cc,snappy-stubs-internal.cc,snappy.cc} \
		${mosaic_LIBS:-}

exit 0
