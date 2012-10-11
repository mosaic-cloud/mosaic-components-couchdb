#!/bin/bash

set -e -E -u -o pipefail -o noclobber -o noglob -o braceexpand || exit 1
trap 'printf "[ee] failed: %s\n" "${BASH_COMMAND}" >&2' ERR || exit 1

test "${#}" -eq 0

cd -- "$( dirname -- "$( readlink -e -- "${0}" )" )"

rm -Rf ./.generated
mkdir ./.generated

VERSION=1.2.0

cp -T ./repositories/couchdb/couch.app.tpl.in ./.generated/couch.app
cp -T ./repositories/couchdb/priv/stat_descriptions.cfg.in ./.generated/stat_descriptions.cfg
cp -T ./repositories/couchdb-etc/couchdb/default.ini.tpl.in ./.generated/default.ini
cp -T ./repositories/couchdb-etc/couchdb/local.ini ./.generated/local.ini

sed -r \
		-e 's!@version@!'"${VERSION}"'!g' \
		-e 's!%localconfdir%/@defaultini@!/dev/null!g' \
		-e 's!%localconfdir%/@localini@!/dev/null!g' \
		-e 's!@package_name@!CouchDB!g' \
		-i ./.generated/couch.app

sed -r \
		-e 's!(\{modules, \[)@modules@(\]\})!\1'"$(
				find -H ./repositories/couchdb -type f -name '*.erl' -exec basename -- {} .erl \; \
				| tr '\n' ','
		)"'\2!g' \
		-e 's!(\{modules, \[)(([a-z]([a-z0-9_]+[a-z0-9])?,)*)([a-z]([a-z0-9_]+[a-z0-9])?),(\]\})!\1\2\5\7!g' \
		-i ./.generated/couch.app

sed -r \
		-e 's!%localstatelibdir%!./data/db!g' \
		-e 's!%localstaterundir%!./data/run!g' \
		-e 's!%localstatelogdir%!./data/log!g' \
		-e 's!%couchprivlibdir%!./lib/couch/priv/lib!g' \
		-e 's!%localbuilddatadir%!./lib/couch/priv!g' \
		-e 's!%localdatadir%!./lib/couch/priv!g' \
		-e 's!%bindir%/%couchjs_command_name%!./lib/couch/priv/lib/couchjs!g' \
		-i ./.generated/default.ini

mkdir ./.generated/server
cat ./repositories/couchdb-share/server/{json2,filter,mimeparse,render,state,util,validate,views,loop}.js >./.generated/server/main.js
cat ./repositories/couchdb-share/server/{json2,filter,mimeparse,render,state,util,validate,views,coffee-script,loop}.js >./.generated/server/main-coffee.js

cp -T ./repositories/couchdb/priv/spawnkillable/couchspawnkillable.sh ./.generated/couchspawnkillable
chmod +x ./.generated/couchspawnkillable

cat >./.generated/config.h <<-'EOS'
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

gcc -shared -o ./.generated/couch_ejson_compare_nif.so \
		-I ./repositories/couchdb/priv/couch_ejson_compare \
		-I "${mosaic_pkg_erlang:-/usr/lib/erlang}/usr/include" \
		-L "${mosaic_pkg_erlang:-/usr/lib/erlang}/usr/lib" \
		${mosaic_CFLAGS:-} ${mosaic_LDFLAGS:-} \
		./repositories/couchdb/priv/couch_ejson_compare/couch_ejson_compare.c \
		${mosaic_LIBS:-}

gcc -shared -o ./.generated/couch_icu_driver.so \
		-I ./repositories/couchdb/priv/icu_driver \
		-I "${mosaic_pkg_erlang:-/usr/lib/erlang}/usr/include" \
		-L "${mosaic_pkg_erlang:-/usr/lib/erlang}/usr/lib" \
		${mosaic_CFLAGS:-} ${mosaic_LDFLAGS:-} \
		./repositories/couchdb/priv/icu_driver/couch_icu_driver.c \
		-licui18n \
		${mosaic_LIBS:-}

gcc -o ./.generated/couchjs \
		-include ./.generated/config.h \
		-I ./.generated \
		-I ./repositories/couchdb/priv/couch_js \
		-I ./repositories/js-package/include/js \
		-L ./repositories/js-package/lib \
		-I ./repositories/nspr-package/include \
		-L ./repositories/nspr-package/lib \
		-I "${mosaic_pkg_erlang:-/usr/lib/erlang}/usr/include" \
		-L "${mosaic_pkg_erlang:-/usr/lib/erlang}/usr/lib" \
		${mosaic_CFLAGS:-} ${mosaic_CXXFLAGS:-} ${mosaic_LDFLAGS:-} \
		./repositories/couchdb/priv/couch_js/{http.c,sm185.c,utf8.c,util.c} \
		./repositories/js-package/lib/libmozjs185-1.0.a \
		./repositories/nspr-package/lib/lib{nspr4,plc4,plds4}.a \
		-lm -lpthread -lcrypt -lstdc++ \
		${mosaic_LIBS:-}

mkdir ./.generated/lib
cp -t ./.generated/lib \
		./.generated/couchjs \
		./.generated/couch_ejson_compare_nif.so \
		./.generated/couch_icu_driver.so

#cp -T /usr/lib/couchdb/bin/couchjs ./.generated/lib/couchjs
#cp -T /usr/lib/couchdb/erlang/lib/couch-1.2.0/priv/lib/couch_ejson_compare.so ./.generated/lib/couch_ejson_compare_nif.so
#cp -T /usr/lib/couchdb/erlang/lib/couch-1.2.0/priv/lib/couch_icu_driver.so ./.generated/couch_icu_driver.so

exit 0
