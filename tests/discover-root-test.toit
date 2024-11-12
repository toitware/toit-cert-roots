// Copyright (C) 2024 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/TESTS_LICENSE file.

import expect show *
import ..examples.discover-root as discover-root

main:
  result := discover-root.discover-root --uri="https://toitlang.org"
  expect-not-null result
