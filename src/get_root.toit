// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import tls

import .certificate-roots

/**
Takes an exception caused by trying to connect to an HTTPS
  server without the correct root cert.  Returns the correct
  root cert if it is in the known root list.  Returns null
  if the exception was caused by something else, or the root
  is unknown.
Due to memory limitations it is not normally possible to add
  all known root certificates to a socket.  Therefore you
  will normally add the one root certificate that you need.
  If you want to be able to connect to arbitrary HTTPS servers
  you can make an attempt with one root (eg $GLOBALSIGN-ROOT-CA)
  and then use this to parse the exception and get the correct
  root for a second attempt.
*/
get-root-from-exception exception/string -> tls.RootCertificate?:
  INTRO ::= "Site relies on unknown root certificate: '"
  if not exception.starts-with INTRO: return null
  cn-index := exception.index-of "CN="
  if cn-index == -1: return null
  cn-index += 3
  cn-end-index := exception[cn-index..].index-of ","
  if cn-end-index == -1:
    cn-end-index = exception[cn-index..].index-of "'"
  if cn-end-index == -1: return null
  common-name := exception[cn-index..][..cn-end-index]
  cert := MAP.get common-name
  if cert == null: return null
  print "Found cert $common-name"
  return cert
