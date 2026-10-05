defmodule Runtimes.Common do
  @moduledoc false

  @default_packages_path "packages"
  @default_nifs_path "nifs"

  def host do
    case :os.type() do
      {:unix, :linux} -> "linux-x86_64"
      {:unix, :darwin} -> "darwin-x86_64"
    end
  end

  def source_path(arch) do
    Path.join(Mix.Project.deps_path(), "arch-#{arch}")
  end

  def build_path(arch) do
    Path.join(Mix.Project.build_path(), "arch-#{arch}")
  end

  def staging_path(arch) do
    Path.join(build_path(arch), "staging")
  end

  # Returns list of directories to look for packages makefiles
  def packages_path do
    Mix.Project.config()[:packages_path] ||
      [
        Path.join(
          Path.dirname(Mix.Project.project_file()),
          @default_packages_path
        )
      ]
  end

  # Returns list of directories to look for NIF makefiles
  def nifs_path do
    Mix.Project.config()[:nifs_path] ||
      [
        Path.join(
          Path.dirname(Mix.Project.project_file()),
          @default_nifs_path
        )
      ]
  end

  def scripts_path do
    Path.join(
      Path.dirname(Mix.Project.project_file()),
      "scripts"
    )
  end

  def install_program() do
    case :os.type() do
      {:unix, :linux} -> "/usr/bin/install -c -s --strip-program=llvm-strip"
      {:unix, :darwin} -> "/usr/bin/install -c"
    end
  end

  def erts_version(arch_id) do
    vsn_path =
      Path.join(
        build_path(arch_id),
        "otp/erts/vsn.mk"
      )

    content = File.read!(vsn_path)
    [[_, vsn]] = Regex.scan(~r/VSN *= *([0-9\.]+)/, content)
    vsn
  end
end
