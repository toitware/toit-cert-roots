// Copyright (C) 2022 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/TESTS_LICENSE file.

import certificate_roots
import expect show *

main:
  dst := certificate_roots.DST_ROOT_CA_X3
  cyber := certificate_roots.CYBERTRUST_GLOBAL_ROOT
  globalsign := certificate_roots.GLOBALSIGN_ROOT_CA_R2
  expect_not_equals dst cyber
  expect_not_equals dst globalsign
  expect_not_equals cyber globalsign
