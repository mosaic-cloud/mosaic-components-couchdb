#!/bin/bash

set -e -E -u -o pipefail || exit 1
test "${#}" -eq 0

cd -- "$( dirname -- "$( readlink -e -- "${0}" )" )"

rm -Rf ./.generated
mkdir ./.generated

mkdir ./.generated/build
mkdir ./.generated/install

workbench="$( readlink -e -- . )"

configure_arguments=(
	--prefix="${workbench}/.generated/install"
)
make_arguments=(
	-C "${workbench}/.generated/build"
)

configure_env=( x=x )
if test -n "${mosaic_CFLAGS:-}" ; then configure_env+=( "CFLAGS=${mosaic_CFLAGS:-}" ) ; fi
if test -n "${mosaic_CXXFLAGS:-}" ; then configure_env+=( "CXXFLAGS=${mosaic_CXXFLAGS:-}" ) ; fi
if test -n "${mosaic_LDFLAGS:-}" ; then configure_env+=( "LDFLAGS=${mosaic_LDFLAGS:-}" ) ; fi
if test -n "${mosaic_LIBS:-}" ; then configure_env+=( "LIBS=${mosaic_LIBS:-}" ) ; fi

(
	cd ./.generated/build || exit 1
	exec env "${configure_env[@]}" \
		"${workbench}/repositories/nspr/configure" "${configure_arguments[@]}" || exit 1
)

make "${make_arguments[@]}"

make install "${make_arguments[@]}"

exit 0
