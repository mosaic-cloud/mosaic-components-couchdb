#!/bin/bash

set -e -E -u -o pipefail -o noclobber -o noglob -o braceexpand || exit 1
trap 'printf "[ee] failed: %s\n" "${BASH_COMMAND}" >&2' ERR || exit 1

test "${#}" -eq 0

cd -- "$( dirname -- "$( readlink -e -- "${0}" )" )"
test -d "${_generate_outputs}"

VERSION=1.2.0

cp -T ./repositories/couchdb/couch.app.tpl.in "${_generate_outputs}/couch.app"
cp -T ./repositories/couchdb/priv/stat_descriptions.cfg.in "${_generate_outputs}/stat_descriptions.cfg"
cp -T ./repositories/couchdb-etc/couchdb/default.ini.tpl.in "${_generate_outputs}/default.ini"
cp -T ./repositories/couchdb-etc/couchdb/local.ini "${_generate_outputs}/local.ini"

sed -r \
		-e 's!@version@!'"${VERSION}"'!g' \
		-e 's!%localconfdir%/@defaultini@!/dev/null!g' \
		-e 's!%localconfdir%/@localini@!/dev/null!g' \
		-e 's!@package_name@!CouchDB!g' \
		-i "${_generate_outputs}/couch.app"

sed -r \
		-e 's!(\{modules, \[)@modules@(\]\})!\1'"$(
				find -H ./repositories/couchdb -type f -name '*.erl' -exec basename -- {} .erl \; \
				| tr '\n' ','
		)"'\2!g' \
		-e 's!(\{modules, \[)(([a-z]([a-z0-9_]+[a-z0-9])?,)*)([a-z]([a-z0-9_]+[a-z0-9])?),(\]\})!\1\2\5\7!g' \
		-i "${_generate_outputs}/couch.app"

sed -r \
		-e 's!%localstatelibdir%!./data/db!g' \
		-e 's!%localstaterundir%!./data/run!g' \
		-e 's!%localstatelogdir%!./data/log!g' \
		-e 's!%couchprivlibdir%!./lib/couch/priv/lib!g' \
		-e 's!%localbuilddatadir%!./lib/couch/priv!g' \
		-e 's!%localdatadir%!./lib/couch/priv!g' \
		-e 's!%bindir%/%couchjs_command_name%!./lib/couch/priv/lib/couchjs!g' \
		-i "${_generate_outputs}/default.ini"

mkdir "${_generate_outputs}/server"
cat ./repositories/couchdb-share/server/{json2,filter,mimeparse,render,state,util,validate,views,loop}.js >"${_generate_outputs}/server/main.js"
cat ./repositories/couchdb-share/server/{json2,filter,mimeparse,render,state,util,validate,views,coffee-script,loop}.js >"${_generate_outputs}/server/main-coffee.js"

cp -T ./repositories/couchdb/priv/spawnkillable/couchspawnkillable.sh "${_generate_outputs}/couchspawnkillable"
chmod +x "${_generate_outputs}/couchspawnkillable"

cat >"${_generate_outputs}/config.h" <<-'EOS'
	#ifndef HAVE_CONFIG_H
	#define HAVE_CONFIG_H
	#define XP_UNIX
	#define _XOPEN_SOURCE
	#define _BSD_SOURCE
	#define COUCHJS_NAME "couchjs"
	#define PACKAGE_NAME "couchjs"
	#define PACKAGE_STRING "couchjs ${VERSION}"
	#define PACKAGE_BUGREPORT "http://developers.mosaic-cloud.eu/"
	#define HAVE_JS_GET_STRING_CHARS_AND_LENGTH 1
	#define JSSCRIPT_TYPE JSObject*
	#endif
EOS

gcc -shared -o "${_generate_outputs}/couch_ejson_compare_nif.so" \
		-I ./repositories/couchdb/priv/couch_ejson_compare \
		-I "${pallur_pkg_erlang:-/usr/lib/erlang}/usr/include" \
		-L "${pallur_pkg_erlang:-/usr/lib/erlang}/usr/lib" \
		-w \
		${pallur_CFLAGS:-} ${pallur_LDFLAGS:-} \
		./repositories/couchdb/priv/couch_ejson_compare/couch_ejson_compare.c \
		${pallur_LIBS:-} \
		-static-libgcc

gcc -shared -o "${_generate_outputs}/couch_icu_driver.so" \
		-I ./repositories/couchdb/priv/icu_driver \
		-I "${pallur_pkg_erlang:-/usr/lib/erlang}/usr/include" \
		-L "${pallur_pkg_erlang:-/usr/lib/erlang}/usr/lib" \
		-w \
		${pallur_CFLAGS:-} ${pallur_LDFLAGS:-} \
		./repositories/couchdb/priv/icu_driver/couch_icu_driver.c \
		${pallur_LIBS:-} \
		-Wl,-Bstatic -licui18n -licuuc -licudata -Wl,-Bdynamic \
		-Wl,-Bstatic -lstdc++ -Wl,-Bdynamic \
		-lm -lpthread \
		-static-libgcc -static-libstdc++

gcc -o "${_generate_outputs}/couchjs" \
		-I "${_generate_outputs}" \
		-I ./repositories/couchdb/priv/couch_js \
		-I "${pallur_pkg_js_1_8_5}/include/js" \
		-L "${pallur_pkg_js_1_8_5}/lib" \
		-I "${pallur_pkg_nspr_4_9}/include" \
		-L "${pallur_pkg_nspr_4_9}/lib" \
		-I "${pallur_pkg_erlang:-/usr/lib/erlang}/usr/include" \
		-L "${pallur_pkg_erlang:-/usr/lib/erlang}/usr/lib" \
		-include "${_generate_outputs}/config.h" \
		-w -fpermissive \
		${pallur_CXXFLAGS:-} ${pallur_LDFLAGS:-} \
		./repositories/couchdb/priv/couch_js/{http.c,sm185.c,utf8.c,util.c} \
		-Wl,-Bstatic -lmozjs185-1.0 -lnspr4 -lplc4 -lplds4 -Wl,-Bdynamic \
		${pallur_LIBS:-} \
		-Wl,-Bstatic -lstdc++ -Wl,-Bdynamic \
		-lm -lpthread \
		-static-libgcc -static-libstdc++

mkdir "${_generate_outputs}/lib"
cp -t "${_generate_outputs}/lib" \
		"${_generate_outputs}/couchjs" \
		"${_generate_outputs}/couch_ejson_compare_nif.so" \
		"${_generate_outputs}/couch_icu_driver.so"

exit 0
