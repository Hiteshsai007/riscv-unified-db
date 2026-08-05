# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# typed: false
# frozen_string_literal: true

require_relative "test_helper"

# Load every test file in this directory instead of enumerating them by hand.
# The explicit list used to drift: files added without updating it (and files
# it omitted) silently never ran in `./do test:udb:unit`.
# See https://github.com/riscv/riscv-unified-db/issues/2380
Dir[File.join(__dir__, "test_*.rb")].sort.each do |f|
  require f unless f.end_with?("test_helper.rb")
end
