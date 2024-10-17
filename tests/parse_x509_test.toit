// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/TESTS_LICENSE file.

import certificate-roots
import expect show *

main:
  baltimore := certificate-roots.BALTIMORE-CYBERTRUST-ROOT
  amazon-1 := certificate-roots.AMAZON-ROOT-CA-1
  comodo := certificate-roots.COMODO-AAA-SERVICES-ROOT
  expect-not-equals baltimore amazon-1
  expect-not-equals amazon-1 comodo
  expect-not-equals comodo baltimore
