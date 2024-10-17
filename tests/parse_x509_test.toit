// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/TESTS_LICENSE file.

import certificate_roots
import expect show *

main:
  baltimore := certificate_roots.BALTIMORE-CYBERTRUST-ROOT
  amazon-1 := certificate_roots.AMAZON-ROOT-CA-1
  comodo := certificate_roots.COMODO-AAA-SERVICES-ROOT
  expect_not_equals baltimore amazon-1
  expect_not_equals amazon-1 comodo
  expect_not_equals comodo baltimore
