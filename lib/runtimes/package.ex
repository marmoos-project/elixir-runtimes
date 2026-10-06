defmodule Runtimes.Package do
  @moduledoc """
  Describe a package for embedding into erlang runtime.

  Package can be a NIF or required library for building NIFs.

  # General structure of a package

  A package is described by a Makefile.

  It must provide 3 targets: `build`, `clean`, and `install`.

  Environment variables can be used to customize the build process.

  Base environment (available for all platforms) includes:
  - `PLATFORM`
  - `ARCH`
  - `ARCH_NAME`
  - `ARCH_XCOMP`
  - `DEPS_PATH`
  - `BUILD_PATH`
  - `STAGING_PATH`

  It includes also platform specific environment variables.

  Makefiles can also define variable that will be used to collect package metadata:
  - `REPO` - required, git repository URL
  - `TAG` - git tag or commit hash, default to `master`
  - `DEPS` - space separated list of dependencies
  - `PLATFORMS` - optional, space separated list of supported platforms
  - `EXTRA_RUNTIME` - optional, space separated list of extra runtime libraries required by the package

  # NIF

  By default, `:runtimes` app look for NIF makefiles in `nifs` directory. This can be overriden with project's `:nifs_path` configuration.

  # Packages

  By default, `:runtimes` app look for package makefiles in `packages` directory. This can be overriden with project's `:packages_path` configuration.

  `openssl` package is required by OTP and its definition is included in `:runtimes` app.
  """
  alias Runtimes.Platform

  defstruct mk: nil,
            name: nil,
            source_dir: nil,
            deps: [],
            repo: nil,
            tag: nil,
            archs: [],
            platforms: [],
            manager: :runtimes,
            extra_runtime: [],
            type: nil

  @type t :: %__MODULE__{
          mk: String.t() | nil,
          name: String.t() | nil,
          source_dir: String.t() | nil,
          deps: [String.t()],
          repo: String.t() | nil,
          tag: String.t() | nil,
          archs: [String.t()],
          platforms: [String.t()],
          extra_runtime: [String.t()],
          type: :nif | :package | nil
        }

  def create(makefile), do: create(makefile, nil)

  def create(makefile, type) do
    name = Path.basename(makefile, ".mk")
    source_dir = Path.join(Mix.Project.deps_path(), name)

    %__MODULE__{
      name: name,
      mk: makefile,
      source_dir: source_dir,
      type: type
    }
    |> read_deps()
    |> read_repo()
    |> read_platforms()
    |> read_extra_runtime()
  end

  def checked_out?(%__MODULE__{source_dir: source_dir}) do
    File.exists?(source_dir)
  end

  def ensure_type!(%__MODULE__{type: type} = package, type) do
    package
  end

  def ensure_type!(%__MODULE__{type: _type} = package, type) do
    Mix.raise("Package #{package.name} is not of type #{type}")
  end

  def ensure_platform!(%__MODULE__{} = package, %Platform{} = platform) do
    unless supports_platform?(package, platform) do
      Mix.raise("Package #{package.name} does not support platform #{platform.name}")
    end

    package
  end

  @doc """
  Returns true if the package supports the given platform.
  """
  def supports_platform?(%__MODULE__{} = package, %Platform{} = platform) do
    package.platforms == [] or platform.name in package.platforms
  end

  defp read_deps(%__MODULE__{} = package) do
    deps =
      package.mk
      |> makefile_var("DEPS")
      |> String.split()

    %__MODULE__{package | deps: deps}
  end

  defp read_extra_runtime(%__MODULE__{} = package) do
    extra_runtime =
      package.mk
      |> makefile_var("EXTRA_RUNTIME")
      |> String.split()

    %__MODULE__{package | extra_runtime: extra_runtime}
  end

  defp read_platforms(%__MODULE__{} = package) do
    platforms =
      package.mk
      |> makefile_var("PLATFORMS")
      |> String.split()

    %__MODULE__{package | platforms: platforms}
  end

  defp read_repo(%__MODULE__{} = package) do
    repo =
      package.mk
      |> makefile_var("REPO")
      |> String.trim()

    tag =
      package.mk
      |> makefile_var("TAG")
      |> String.trim()

    set_repo(package, repo, tag)
  end

  defp set_repo(%__MODULE__{} = package, "", _) do
    raise "Package #{package.name} does not have a repository URL set in its makefile"
  end

  defp set_repo(%__MODULE__{} = package, repo, tag) do
    tag = if tag == "", do: "master", else: tag
    %__MODULE__{package | repo: repo, tag: tag}
  end

  defp makefile_var(makefile, name) do
    printer = "@echo $(#{name})"

    {out, 0} =
      System.cmd(
        "make",
        ["-f", makefile, "-s", "--eval=print:; #{printer}", "print"]
      )

    out
  end
end
