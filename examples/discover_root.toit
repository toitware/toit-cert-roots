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
import certificate-roots

network-interface ::= net.open

main:

main args:
  if args.size != 1:
    print "Usage: discover_root.toit <uri>"
    return

  uri := args[0]

  discover-root --uri=uri

discover-root --uri/string -> string?:
  names := []
  certs := []

  certificate-roots.MAP.do: | name cert |
    names.add name
    certs.add cert

  // This will not work on small devices since it parses all certificates
  // at once.  Once parsed, the memory is not freed, so there's no easy
  // way around this.
  result := binary-split names certs --uri=uri

  if not result:
    print "None of the certificate roots was suitable for connecting to $uri"
  return result

binary-split names/List certs/List --uri/string -> string?:

  print "."

  exception := catch:
    client := http.Client.tls network-interface --root-certificates=certs
    try:
      response := client.get --uri=uri
    finally:
      client.close

  if exception:
    if exception.to-string.starts-with "Site relies on unknown root":
      return null
    if exception.to-string.starts-with "X509 - Certificate verification failed":
      return null
    if exception.to-string.starts-with "Unknown root certificate":
      return null
    throw exception

  if names.size == 1:
    print "Successful connection to $uri with $names[0]"
    return names[0]

  else:
    // names.size >= 2.
    l-names := names[..names.size / 2]
    r-names := names[names.size / 2..]
    l-certs := certs[..certs.size / 2]
    r-certs := certs[certs.size / 2..]

    return binary-split l-names l-certs --uri=uri or
        binary-split r-names r-certs --uri=uri
