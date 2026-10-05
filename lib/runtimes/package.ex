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
  - `DEPS`
  - `REPO`
  - `TAG`
  - `PLATFORMS`
  - `EXTRA_RUNTIME_LIBS`

  # NIF

  By default, `:runtimes` app look for NIF makefiles in `nifs` directory. This can be overriden with project's `:nifs_path` configuration.

  # Packages

  By default, `:runtimes` app look for package makefiles in `packages` directory. This can be overriden with project's `:packages_path` configuration.

  `openssl` package is required by OTP and its definition is included in `:runtimes` app.
  """
  defstruct mk: nil,
            name: nil,
            source_dir: nil,
            deps: [],
            repo: nil,
            tag: nil,
            archs: [],
            platforms: [],
            manager: :runtimes

  @type t :: %__MODULE__{
          mk: String.t() | nil,
          name: String.t() | nil,
          source_dir: String.t() | nil,
          deps: [String.t()],
          repo: String.t() | nil,
          tag: String.t() | nil,
          archs: [String.t()],
          platforms: [String.t()],
          manager: :runtimes | :mix
        }
end
