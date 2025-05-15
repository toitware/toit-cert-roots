// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import certificate-roots show *
import expect show *
import net
import net.tcp
import net.x509 as net
import system
import system show platform
import tls

expect-error name [code]:
  error := catch code
  expect: error.contains name

monitor LimitLoad:
  current := 0
  has-test-failure := null
  // FreeRTOS does not have enough memory to run in parallel.
  concurrent-processes ::= platform == system.PLATFORM-FREERTOS ? 1 : 4

  inc:
    await: current < concurrent-processes
    current++

  flush:
    await: current == 0

  test-failures:
    await: current == 0
    return has-test-failure

  log-test-failure message:
    has-test-failure = message

  dec:
    current--

load-limiter := LimitLoad

main:
  install-common-trusted-roots
  network := net.open
  try:
    run-tests network
  finally:
    network.close

run-tests network/net.Client:
  amazon-ip := (network.resolve "amazon.com").first

  working := [
    "amazon.com",
    "adafruit.com",

    // Connect to the IP address at the TCP level, but verify the cert name.
    "$amazon-ip/amazon.com",

    "dkhostmaster.dk",
    "dmi.dk",
    "example.com",
    "pravda.ru",
    "elpriser.nu",
    "coinbase.com",
    "appspot.com",
    "s3-us-west-1.amazonaws.com",
    "helsinki.fi",
    "lund.se",
    "web.whatsapp.com",
    "digimedia.com",
    "european-union.europa.eu",
    "elpais.es",  // Starfield root.
    "vw.de",
    "moxie.org",
    "signal.org",
    "supabase.com",
    "github.com",
    ]
  working.do: | site |
    test-site network site
    if load-limiter.has-test-failure: throw load-limiter.has-test-failure  // End early if we have a test failure.
  if load-limiter.test-failures:
    throw load-limiter.has-test-failure

test-site network/net.Client url:
  host := url
  extra-info := null
  if host.contains "/":
    parts := host.split "/"
    host = parts[0]
    extra-info = parts[1]
  port := 443
  if url.contains ":":
    array := url.split ":"
    host = array[0]
    port = int.parse array[1]
  load-limiter.inc
  task:: working-site network host port extra-info

working-site network/net.Client host port expected-certificate-name:
  error := true
  try:
    connect-to-site network host port expected-certificate-name
    error = false
  finally:
    if error:
      load-limiter.log-test-failure "*** Incorrectly failed to connect to $host ***"
    load-limiter.dec

reported-error := false

connect-to-site network/net.Client host port expected-certificate-name:
  bytes := 0
  connection := null

  raw/tcp.Socket? := null
  try:
    raw = network.tcp-connect host port

    socket := tls.Socket.client raw
      --server-name=expected-certificate-name or host

    try:
      writer := socket.out
      writer.write """GET / HTTP/1.1\r\nHost: $host\r\nConnection: close\r\n\r\n"""
      print "$host: $((socket as any).session_.mode == tls.SESSION-MODE-TOIT ? "Toit mode" : "MbedTLS mode")"

      while data := socket.in.read:
        bytes += data.size

    finally:
      socket.close
  finally: | is-exception _ |
    if raw: raw.close
    if connection: connection.close

    print "Read $bytes bytes from https://$host$(port == 443 ? "" : ":$port")/"
    if is-exception and not reported-error:
      print "** ERROR: $host"
      reported-error = true
