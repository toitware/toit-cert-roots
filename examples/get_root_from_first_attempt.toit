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
URL ::= "/"               // Replace with the URL part after the domain.

NETWORK_INTERFACE ::= net.open

main:
  exception := try_with_root certificate_roots.GLOBALSIGN_ROOT_CA
  if exception:
    root := certificate_roots.get_root_from_exception exception
    if root:
      exception = try_with_root root
  if exception:
    print "Failed to connect: $exception"

try_with_root cert/net.Certificate -> string?:
  exception := catch:
    tcp := NETWORK_INTERFACE.tcp_connect HOST 443
    socket := tls.Socket.client tcp
      --server_name=HOST
      --root_certificates=[cert]

    connection := http.Connection socket HOST
    try:
      request := connection.new_request "GET" URL
      response := request.send
      bytes := 0
      while data := response.read:
        bytes += data.size
      print "Read $bytes bytes from https://$HOST$URL"
    finally:
      connection.close

  return exception
