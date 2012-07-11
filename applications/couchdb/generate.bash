#!/bin/bash

set -e -E -u -o pipefail || exit 1
test "${#}" -eq 0

cd -- "$( dirname -- "$( readlink -e -- "${0}" )" )"

rm -Rf ./.generated
mkdir ./.generated

VERSION=1.2.0

cp -T ./repositories/couchdb/couch.app.tpl.in ./.generated/couch.app
cp -T ./repositories/etc/couchdb/default.ini.tpl.in ./.generated/default.ini
cp -T ./repositories/etc/couchdb/local.ini ./.generated/local.ini
cp -T ./repositories/couchdb/priv/stat_descriptions.cfg.in ./.generated/stat_descriptions.cfg

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
cat ./repositories/share/server/{json2,filter,mimeparse,render,state,util,validate,views,loop}.js >./.generated/server/main.js
cat ./repositories/share/server/{json2,filter,mimeparse,render,state,util,validate,views,coffee-script,loop}.js >./.generated/server/main-coffee.js

cp -T ./repositories/couchdb/priv/spawnkillable/couchspawnkillable.sh ./.generated/couchspawnkillable
chmod +x ./.generated/couchspawnkillable

# !!!!
mkdir ./.generated/lib
cp -t ./.generated/lib \
		/usr/lib/couchdb/bin/couchjs \
		/usr/lib/couchdb/erlang/lib/couch-1.2.0/priv/lib/couch_ejson_compare.so \
		/usr/lib/couchdb/erlang/lib/couch-1.2.0/priv/lib/couch_icu_driver.so
exit 0
# !!!!

cat >./.generated/config.h <<-'EOS'
	#define COUCHJS_NAME "couchjs"
	#define PACKAGE_NAME "couchjs"
	#define PACKAGE_STRING "couchjs"
	#define PACKAGE_BUGREPORT "wtf"
EOS

gcc -shared -o ./.generated/couch_ejson_compare_nif.so \
		-I ./repositories/couchdb/priv/couch_ejson_compare \
		-I "${mosaic_pkg_erlang:-/usr/lib/erlang}/usr/include" \
		-L "${mosaic_pkg_erlang:-/usr/lib/erlang}/usr/lib" \
		${mosaic_CFLAGS:-} ${mosaic_LDFLAGS:-} \
		./repositories/couchdb/priv/couch_ejson_compare/couch_ejson_compare.c \
		${mosaic_LIBS:-}

gcc -shared -o ./.generated/couch_icu_driver.so \
		-I "${mosaic_pkg_erlang:-/usr/lib/erlang}/usr/include" \
		-L "${mosaic_pkg_erlang:-/usr/lib/erlang}/usr/lib" \
		${mosaic_CFLAGS:-} ${mosaic_LDFLAGS:-} \
		./repositories/couchdb/priv/icu_driver/couch_icu_driver.c \
		${mosaic_LIBS:-}

make -C ./repositories/erlang-js/c_src clean
make -C ./repositories/erlang-js/c_src js

gcc -shared -o ./.generated/couchjs \
		-I ./.generated \
		-L ./repositories/erlang-js/c_src/system/lib \
		-I ./repositories/erlang-js/c_src/system/include/js \
		-I ./repositories/erlang-js/c_src/system/include/nspr \
		-I ./repositories/couchdb/priv/couch_js \
		-I "${mosaic_pkg_erlang:-/usr/lib/erlang}/usr/include" \
		-L "${mosaic_pkg_erlang:-/usr/lib/erlang}/usr/lib" \
		${mosaic_CFLAGS:-} ${mosaic_LDFLAGS:-} \
		-DXP_UNIX \
		./repositories/couchdb/priv/couch_js/{http.c,sm180.c,utf8.c,util.c} \
		./repositories/erlang-js/c_src/system/lib/{libjs.a,libnspr4.a} \
		${mosaic_LIBS:-}

mkdir ./.generated/lib
cp -t ./.generated/lib \
		./.generated/couchjs \
		./.generated/couch_ejson_compare_nif.so \
		./.generated/couch_icu_driver.so

exit 0
