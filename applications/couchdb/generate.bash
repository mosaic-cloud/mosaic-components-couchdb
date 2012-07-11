#!/bin/bash

set -e -E -u -o pipefail || exit 1
test "${#}" -eq 0

cd -- "$( dirname -- "$( readlink -e -- "${0}" )" )"

rm -Rf ./.generated
mkdir ./.generated

VERSION=1.3.0

find -H ./repositories/couchdb -type f -name '*.erl' -exec basename -- {} .erl \; \
	>./.generated/couch_modules.txt

cp -T ./repositories/couchdb/couch.app.tpl.in ./.generated/couch.app

sed -r -e 's!@version@!'"${VERSION}"'!g' -i ./.generated/couch.app

sed -r \
		-e 's!%localconfdir%/@defaultini@!/dev/null!g' \
		-e 's!%localconfdir%/@localini@!/dev/null!g' \
		-e 's!@package_name@!CouchDB!g' \
		-i ./.generated/couch.app

sed -r \
		-e 's!(\{modules, \[)@modules@(\]\})!\1'"$( tr '\n' ',' <./.generated/couch_modules.txt )"'\2!g' \
		-e 's!(\{modules, \[)(([a-z]([a-z0-9_]+[a-z0-9])?,)*)([a-z]([a-z0-9_]+[a-z0-9])?),(\]\})!\1\2\5\7!g' \
		-i ./.generated/couch.app

exit 0
