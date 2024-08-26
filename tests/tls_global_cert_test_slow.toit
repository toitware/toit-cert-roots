// Copyright (C) 2023 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/LICENSE file.

import certificate_roots show *
import expect show *
import net
import net.tcp
import net.x509 as net
import system
import system show platform
import tls
import writer

expect_error name [code]:
  error := catch code
  expect: error.contains name

monitor LimitLoad:
  current := 0
  has_test_failure := null
  // FreeRTOS does not have enough memory to run in parallel.
  concurrent_processes ::= platform == system.PLATFORM-FREERTOS ? 1 : 4

  inc:
    await: current < concurrent_processes
    current++

  flush:
    await: current == 0

  test_failures:
    await: current == 0
    return has_test_failure

  log_test_failure message:
    has_test_failure = message

  dec:
    current--

load_limiter := LimitLoad

main:
  install_common_trusted_roots
  network := net.open
  try:
    run_tests network
  finally:
    network.close

run_tests network/net.Client:
  amazon-ip := (network.resolve "amazon.com").first

  working := [
    "amazon.com",
    "adafruit.com",

    // Connect to the IP address at the TCP level, but verify the cert name.
    "$amazon-ip/amazon.com",

    "dkhostmaster.dk",
    "dmi.dk",
    "pravda.ru",
    "elpriser.nu",
    "coinbase.com",
    "appspot.com",
    "s3-us-west-1.amazonaws.com",
    "helsinki.fi",
    "lund.se",
    "web.whatsapp.com",
    "digimedia.com",
    "european-union.europa.eu",  // Starfield root.
    "elpais.es",  // Starfield root.
    "vw.de",  // Starfield root.
    "moxie.org",  // Starfield root.
    "signal.org",  // Starfield root.
    ]
  working.do: | site |
    test_site network site
    if load_limiter.has_test_failure: throw load_limiter.has_test_failure  // End early if we have a test failure.
  if load_limiter.test_failures:
    throw load_limiter.has_test_failure

test_site network/net.Client url:
  host := url
  extra_info := null
  if host.contains "/":
    parts := host.split "/"
    host = parts[0]
    extra_info = parts[1]
  port := 443
  if url.contains ":":
    array := url.split ":"
    host = array[0]
    port = int.parse array[1]
  load_limiter.inc
  task:: working_site network host port extra_info

working_site network/net.Client host port expected_certificate_name:
  error := true
  try:
    connect_to_site network host port expected_certificate_name
    error = false
  finally:
    if error:
      load_limiter.log_test_failure "*** Incorrectly failed to connect to $host ***"
    load_limiter.dec

connect_to_site network/net.Client host port expected_certificate_name:
  bytes := 0
  connection := null

  raw/tcp.Socket? := null
  try:
    raw = network.tcp-connect host port

    socket := tls.Socket.client raw
      --server_name=expected_certificate_name or host

    try:
      writer := socket.out
      writer.write """GET / HTTP/1.1\r\nHost: $host\r\nConnection: close\r\n\r\n"""
      print "$host: $((socket as any).session_.mode == tls.SESSION_MODE_TOIT ? "Toit mode" : "MbedTLS mode")"

      while data := socket.in.read:
        bytes += data.size

    finally:
      socket.close
  finally:
    if raw: raw.close
    if connection: connection.close

    print "Read $bytes bytes from https://$host$(port == 443 ? "" : ":$port")/"
