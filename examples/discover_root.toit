// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

/**
An example that shows how to find out which root certificate
  a host uses.  This enables you to pick the right root, rather
  than putting all the roots in your program, which would explode
  the size. You can run a modified version of this on your host
  workstation (eg with `jag -d host discover_root.toit`), and use
  the output to pick the right root for your device.
*/

import net
import net.x509 as net
import http
import tls
import certificate_roots

HOST ::= "ecc256.badssl.com"  // Replace with the host you want to connect to.
PATH ::= "/"            // Replace with the path part after the domain.

network_interface ::= net.open
found_one_that_worked := false

main:
  names := []
  certs := []

  certificate_roots.MAP.do: | name cert |
    names.add name
    certs.add cert

  // This will not work on small devices since it parses all certificates
  // at once.  Once parsed, the memory is not freed, so there's no easy
  // way around this.
  binary_split names certs

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
    if exception.to_string.starts_with "X509 - Certificate verification failed":
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
