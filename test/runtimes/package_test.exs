defmodule Runtimes.PackageTest do
  use ExUnit.Case, async: true

  alias Runtimes.Package
  alias Runtimes.Platform

  @moduletag :tmp_dir

  defp write_mk(dir, name, content) do
    path = Path.join(dir, name <> ".mk")
    File.write!(path, content)
    path
  end

  defp package(attrs), do: struct!(Package, Keyword.merge([name: "foo"], attrs))

  defp platform(name), do: %Platform{name: name}

  describe "create/1" do
    test "reads metadata from makefile variables", %{tmp_dir: dir} do
      mk =
        write_mk(dir, "foo", """
        REPO = https://example.com/foo.git
        TAG = v1.2.3
        DEPS = openssl zlib
        PLATFORMS = linux android
        EXTRA_RUNTIME = libfoo.so libbar.so

        build:
        \t@true
        """)

      assert %Package{
               mk: ^mk,
               name: "foo",
               type: nil,
               repo: "https://example.com/foo.git",
               tag: "v1.2.3",
               deps: ["openssl", "zlib"],
               platforms: ["linux", "android"],
               extra_runtime: ["libfoo.so", "libbar.so"]
             } = Package.create(mk)
    end

    test "places source_dir under the project's deps path", %{tmp_dir: dir} do
      mk = write_mk(dir, "foo", "REPO = https://example.com/foo.git\n")

      assert Package.create(mk).source_dir == Path.join(Mix.Project.deps_path(), "foo")
    end

    test "defaults optional variables", %{tmp_dir: dir} do
      mk = write_mk(dir, "foo", "REPO = https://example.com/foo.git\n")

      assert %Package{tag: "master", deps: [], platforms: [], extra_runtime: []} =
               Package.create(mk)
    end

    test "expands make variables and tolerates extra whitespace", %{tmp_dir: dir} do
      mk =
        write_mk(dir, "foo", """
        HOST = example.com
        VERSION = 1.0
        REPO = https://$(HOST)/foo.git
        TAG =   v$(VERSION)
        DEPS =   openssl \\
                 zlib
        DEPS += pcre
        """)

      assert %Package{
               repo: "https://example.com/foo.git",
               tag: "v1.0",
               deps: ["openssl", "zlib", "pcre"]
             } = Package.create(mk)
    end

    test "raises when REPO is missing", %{tmp_dir: dir} do
      mk = write_mk(dir, "foo", "TAG = v1.0\n")

      assert_raise RuntimeError, ~r/Package foo does not have a repository URL/, fn ->
        Package.create(mk)
      end
    end
  end

  describe "create/2" do
    test "sets the package type", %{tmp_dir: dir} do
      mk = write_mk(dir, "foo", "REPO = https://example.com/foo.git\n")

      assert Package.create(mk, :nif).type == :nif
      assert Package.create(mk, :package).type == :package
    end
  end

  describe "checked_out?/1" do
    test "is true only when source_dir exists", %{tmp_dir: dir} do
      pkg = package(source_dir: Path.join(dir, "foo"))

      refute Package.checked_out?(pkg)

      File.mkdir_p!(pkg.source_dir)

      assert Package.checked_out?(pkg)
    end

    test "is consistent with a package built by create/1", %{tmp_dir: dir} do
      mk = write_mk(dir, "foo", "REPO = https://example.com/foo.git\n")
      pkg = Package.create(mk)

      assert Package.checked_out?(pkg) == File.exists?(Path.join(Mix.Project.deps_path(), "foo"))
    end
  end

  describe "ensure_type!/2" do
    test "returns the package when the type matches" do
      pkg = package(type: :nif)

      assert Package.ensure_type!(pkg, :nif) == pkg
    end

    test "raises Mix.Error when the type does not match" do
      assert_raise Mix.Error, ~r/Package foo is not of type/, fn ->
        Package.ensure_type!(package(type: :package), :nif)
      end
    end
  end

  describe "supports_platform?/2" do
    test "is true for any platform when platforms is empty" do
      assert Package.supports_platform?(package(platforms: []), platform("linux"))
    end

    test "is true only for listed platforms otherwise" do
      pkg = package(platforms: ["linux", "android"])

      assert Package.supports_platform?(pkg, platform("android"))
      refute Package.supports_platform?(pkg, platform("ios"))
    end
  end

  describe "ensure_platform!/2" do
    test "returns the package when the platform is supported" do
      pkg = package(platforms: ["linux"])

      assert Package.ensure_platform!(pkg, platform("linux")) == pkg

      assert Package.ensure_platform!(package(platforms: []), platform("ios")) ==
               package(platforms: [])
    end

    test "raises Mix.Error when the platform is not supported" do
      assert_raise Mix.Error, "Package foo does not support platform ios", fn ->
        Package.ensure_platform!(package(platforms: ["linux"]), platform("ios"))
      end
    end
  end
end
