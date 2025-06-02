// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

/**
An example that shows how to load another root certificate if
  your first root does not work.  This enables you to contact
  arbitrary hosts without parsing all the certificate roots,
  which would probably cause out-of-memory.
*/

import net
import net.x509 as net
import http
import tls
import certificate_roots

HOST ::= "www.yahoo.com"  // Replace with the host you want to connect to.
PATH ::= "/"              // Replace with the path part after the domain.

network_interface ::= net.open

main:
  certificate_roots.AMAZON-ROOT-CA-1.install
  exception := catch: try-server
  if exception:
    root := certificate_roots.get_root_from_exception exception
    if root:
      root.install
      exception = try_server
  if exception:
    print "Failed to connect: $exception"

try_server -> string?:
  exception := catch:
    client := http.Client.tls network_interface
    response := client.get HOST PATH
    bytes := 0
    while data := response.body.read:
      bytes += data.size
    print "Read $bytes bytes from https://$HOST$PATH"

  return exception
