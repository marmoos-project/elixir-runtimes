defmodule Runtimes.Common do
  @moduledoc false

  @default_packages_dir "packages"
  @default_nifs_dir "nifs"

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

  def default_packages_path do
    Application.app_dir(:runtimes, "priv/#{@default_packages_dir}")
  end

  def default_nifs_path do
    Application.app_dir(:runtimes, "priv/#{@default_nifs_dir}")
  end

  # Returns list of directories to look for packages makefiles
  def packages_path do
    case Mix.Project.config()[:app] do
      :runtimes ->
        [default_packages_path()]

      _ ->
        Mix.Project.config()[:packages_path] ||
          [
            default_packages_path(),
            Path.join(
              Path.dirname(Mix.Project.project_file()),
              @default_packages_dir
            )
          ]
    end
  end

  # Returns list of directories to look for NIF makefiles
  def nifs_path do
    case Mix.Project.config()[:app] do
      :runtimes ->
        [default_nifs_path()]

      _ ->
        Mix.Project.config()[:nifs_path] ||
          [
            default_nifs_path(),
            Path.join(
              Path.dirname(Mix.Project.project_file()),
              @default_nifs_dir
            )
          ]
    end
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
