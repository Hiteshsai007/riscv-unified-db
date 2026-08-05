# Copyright (c) Qualcomm Technologies, Inc. and/or its subsidiaries.
# SPDX-License-Identifier: BSD-3-Clause-Clear

# typed: false
# frozen_string_literal: true

require_relative "test_helper"

require "fileutils"
require "tmpdir"

require "udb"
require "udb/version_spec"
require "udb/obj/database_obj"
require "udb/obj/exception_code"

# Tests for VersionSpec increment_patch/decrement_patch and for the
# DatabaseObject / ExceptionCode / InterruptCode comparison contracts.
class TestVersionSpec < Minitest::Test
  include Udb

  def setup
    @gen_dir = Dir.mktmpdir
    udb_gem_root = (Pathname.new(__dir__) / "..").realpath
    @resolver = Udb::Resolver.new(
      Udb.repo_root,
      schemas_path_override: udb_gem_root / "schemas",
      cfgs_path_override: udb_gem_root / "test" / "mock_cfgs",
      gen_path_override: Pathname.new(@gen_dir),
      std_path_override: udb_gem_root / "test" / "mock_spec" / "isa",
      quiet: true
    )
    @arch = @resolver.cfg_arch_for("_")
  end

  def teardown
    FileUtils.rm_rf @gen_dir
  end

  def test_increment_patch_updates_identity_state
    v = Udb::VersionSpec.new("1.0.0")
    w = v.increment_patch

    assert_equal("1.0.1", w.to_s)
    assert_equal("1.0.1", w.canonical)
    refute v.eql?(w), "incremented spec must not be eql? to its source"
    refute_equal v.hash, w.hash, "incremented spec must hash differently"
    assert_equal(-1, v <=> w)
    assert_equal(2, [v, w].uniq.size)
    assert_nil({ v => :a }[w], "incremented spec must not be a hash key alias of its source")
    assert_equal("1p0p1", w.to_rvi_s)
  end

  def test_increment_patch_from_partial_versions
    assert_equal("1.0.1", Udb::VersionSpec.new("1.0").increment_patch.to_s)
    assert_equal("1p0p1", Udb::VersionSpec.new("1.0").increment_patch.to_rvi_s)
    assert_equal("1.0.1", Udb::VersionSpec.new("1").increment_patch.to_s)
  end

  def test_increment_patch_preserves_pre_release_flag
    w = Udb::VersionSpec.new("1.0.0-pre").increment_patch
    assert_equal("1.0.1-pre", w.to_s)
    assert w.pre
  end

  def test_increment_patch_round_trips_through_interning
    v = Udb::VersionSpec.new("2.5.0")
    w = v.increment_patch
    # The intern cache must not hand back the original object for the new string
    assert_equal("2.5.1", Udb::VersionSpec.new(w.to_s).to_s)
    assert Udb::VersionSpec.new(w.to_s).eql?(w)
  end

  def test_decrement_patch_simple
    w = Udb::VersionSpec.new("1.0.5").decrement_patch
    assert_equal("1.0.4", w.to_s)
    assert_equal("1p0p4", w.to_rvi_s)
    refute Udb::VersionSpec.new("1.0.5").eql?(w)
  end

  def test_decrement_patch_minor_rollover
    w = Udb::VersionSpec.new("1.3.0").decrement_patch
    assert_equal("1.2.9999", w.to_s)
    assert_equal("1p2p9999", w.to_rvi_s)
  end

  def test_decrement_patch_major_rollover
    w = Udb::VersionSpec.new("2.0.0").decrement_patch
    assert_equal("1.9999.9999", w.to_s)
    assert_equal("1p9999p9999", w.to_rvi_s)
  end

  def test_decrement_patch_zero_raises
    assert_raises(RuntimeError) { Udb::VersionSpec.new("0").decrement_patch }
  end

  def test_database_object_comparison_sorts_by_name_within_kind
    arch = @arch
    kind = Udb::DatabaseObject::Kind::Csr
    aaa = Udb::DatabaseObject.new({ "name" => "aaa" }, "p.yaml", arch, kind)
    bbb = Udb::DatabaseObject.new({ "name" => "bbb" }, "p.yaml", arch, kind)

    assert_equal(-1, aaa <=> bbb)
    assert_equal(1, bbb <=> aaa)
    assert_equal(0, aaa <=> Udb::DatabaseObject.new({ "name" => "aaa" }, "p.yaml", arch, kind))
    assert_equal(%w[aaa bbb], [bbb, aaa].sort.map(&:name))
  end

  def test_database_object_comparison_returns_nil_across_kinds
    arch = @arch
    csr = Udb::DatabaseObject.new({ "name" => "aaa" }, "p.yaml", arch, Udb::DatabaseObject::Kind::Csr)
    ext = Udb::DatabaseObject.new({ "name" => "aaa" }, "p.yaml", arch, Udb::DatabaseObject::Kind::Extension)

    assert_nil(csr <=> ext)
  end

  def test_exception_code_and_interrupt_code_are_distinct
    arch = @arch
    ec = Udb::ExceptionCode.new({ "name" => "E1", "num" => 1 }, "p.yaml", arch, Udb::DatabaseObject::Kind::ExceptionCode)
    ic1 = Udb::InterruptCode.new({ "name" => "I1", "num" => 1 }, "p.yaml", arch, Udb::DatabaseObject::Kind::InterruptCode)
    ic2 = Udb::InterruptCode.new({ "name" => "I2", "num" => 2 }, "p.yaml", arch, Udb::DatabaseObject::Kind::InterruptCode)

    # InterruptCode#<=> must compare InterruptCode objects (not reject them)
    assert_equal(-1, ic1 <=> ic2)
    assert_equal(1, ic2 <=> ic1)
    assert_nil(ic1 <=> ec)
    assert_equal([ic1, ic2], [ic2, ic1].sort)

    # InterruptCode#hash must not collide with ExceptionCode#hash for the same num
    refute_equal ec.hash, ic1.hash
    refute_equal ic1.hash, ic2.hash
    refute ic1.eql?(ic2)
    refute ic1.eql?(ec)
  end
end
