#!/bin/sh

# Copyright 2021 Toitware ApS.  All rights reserved.

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# To be run in the tools directory.

rm -rf extract-nss-root-certs
git clone https://github.com/agl/extract-nss-root-certs.git

curl https://hg.mozilla.org/mozilla-central/raw-file/tip/security/nss/lib/ckfw/builtins/certdata.txt -o certdata.txt
go run extract-nss-root-certs/convert_mozilla_certdata.go > certdata.new

python to_toit_source.py < certdata.new > ../src/certificate_roots.toit
