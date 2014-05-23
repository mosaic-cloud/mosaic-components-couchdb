#!/bin/bash

set -e -E -u -o pipefail -o noclobber -o noglob -o braceexpand || exit 1
trap 'printf "[ee] failed: %s\n" "${BASH_COMMAND}" >&2' ERR || exit 1

test "${#}" -eq 0

cd -- "$( dirname -- "$( readlink -e -- "${0}" )" )"
test -d ./.generated

mkdir ./.generated/build
mkdir ./.generated/install

workbench="$( readlink -e -- . )"

configure_arguments=(
	--prefix="${workbench}/.generated/install"
)
make_arguments=(
	-C "${workbench}/.generated/build"
)

configure_env=( )
if test -n "${pallur_CFLAGS:-}" ; then
	configure_env+=( "CFLAGS=-w ${pallur_CFLAGS:-}" )
else
	configure_env+=( "CFLAGS=-w" )
fi
if test -n "${pallur_CXXFLAGS:-}" ; then
	configure_env+=( "CXXFLAGS=-w ${pallur_CXXFLAGS:-}" )
else
	configure_env+=( "CXXFLAGS=-w" )
fi
if test -n "${pallur_LDFLAGS:-}" ; then
	configure_env+=( "LDFLAGS=${pallur_LDFLAGS:-}" )
fi
if test -n "${pallur_LIBS:-}" ; then
	configure_env+=( "LIBS=${pallur_LIBS:-}" )
fi
make_env=( "${configure_env[@]}" )

(
	cd ./.generated/build || exit 1
	exec env "${configure_env[@]}" \
		"${workbench}/repositories/nspr/configure" "${configure_arguments[@]}" || exit 1
)

env "${make_env[@]}" \
	make "${make_arguments[@]}"

env "${make_env[@]}" \
	make install "${make_arguments[@]}"

exit 0
