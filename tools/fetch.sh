#!/bin/sh

# Copyright 2021 Toitware ApS.  All rights reserved.

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

set -e
if [ ! -f fetch.sh ]; then
  echo "Run this script from the tools directory." 1>&2
  exit 1
fi

rm -rf extract-nss-root-certs
git clone https://github.com/agl/extract-nss-root-certs.git
(cd extract-nss-root-certs && patch -p1) < extract.diff

curl -L https://raw.githubusercontent.com/mozilla/gecko-dev/refs/heads/master/security/nss/lib/ckfw/builtins/certdata.txt -o certdata.txt
go run extract-nss-root-certs/convert_mozilla_certdata.go > certdata.new

toit run -- to_toit_source.toit certdata.new > ../src/certificate-roots.toit
