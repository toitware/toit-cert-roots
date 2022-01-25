// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import net
import net.x509 as net
import http
import tls
import certificate_roots

main:
  network_interface := net.open

  host := "www.google.com"
  root_certificates := [
    certificate_roots.GLOBALSIGN_ROOT_CA_R2,
    certificate_roots.GLOBALSIGN_ROOT_CA,
  ]
  client := http.Client.tls network_interface
      --root_certificates=root_certificates
  response := client.get host "/"

  bytes := 0
  while data := response.body.read:
    bytes += data.size

  print "Read $bytes bytes from https://$host/"
