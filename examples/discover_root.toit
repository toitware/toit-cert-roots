// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

/**
An example that shows how to find out which root certificate
  a host uses.  This enables you to pick the right root, rather
  than putting all the roots in your program, which would explode
  the size.
*/

import net
import net.x509 as net
import http
import tls
import certificate_roots

HOST ::= "www.bbc.com"  // Replace with the host you want to connect to.
PATH ::= "/"            // Replace with the path part after the domain.

network_interface ::= net.open
found_one_that_worked := false

main:
  names := []
  cert_texts := []

  certificate_roots.MAP.do: | name cert |
    names.add name
    cert_texts.add cert

  // We can't parse up all certs at once, so do them 12 at a time and avoid
  // running out of memory.
  List.chunk_up 0 names.size 12: | from to size |
    certs := cert_texts[from..to].map: net.Certificate.parse it
    binary_split names[from..to] certs

  if not found_one_that_worked:
    print "None of the certificate roots was suitable for connecting to $HOST"

binary_split names/List certs/List -> none:

  print "."

  exception := catch:
    client := http.Client.tls network_interface --root_certificates=certs
    response := client.get HOST PATH
    // TODO(florian): Don't reach into private variables of response.
    response.connection_.close

  if exception:
    if exception.to_string.starts_with "Site relies on unknown root":
      return
    throw exception

  if names.size == 1:
    print "Successful connection to https://$HOST$PATH with $names[0]"
    found_one_that_worked = true
    return

  else:
    // names.size >= 2.
    l_names := names[..names.size / 2]
    r_names := names[names.size / 2..]
    l_certs := certs[..certs.size / 2]
    r_certs := certs[certs.size / 2..]

    binary_split l_names l_certs
    binary_split r_names r_certs
