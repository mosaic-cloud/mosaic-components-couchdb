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

configure_env=( x=x )
if test -n "${pallur_CFLAGS:-}" ; then configure_env+=( "CFLAGS=${pallur_CFLAGS:-}" ) ; fi
if test -n "${pallur_CXXFLAGS:-}" ; then configure_env+=( "CXXFLAGS=${pallur_CXXFLAGS:-}" ) ; fi
if test -n "${pallur_LDFLAGS:-}" ; then configure_env+=( "LDFLAGS=${pallur_LDFLAGS:-}" ) ; fi
if test -n "${pallur_LIBS:-}" ; then configure_env+=( "LIBS=${pallur_LIBS:-}" ) ; fi

(
	cd ./.generated/build || exit 1
	exec env "${configure_env[@]}" \
		"${workbench}/repositories/nspr/configure" "${configure_arguments[@]}" || exit 1
)

make "${make_arguments[@]}"

make install "${make_arguments[@]}"

exit 0
