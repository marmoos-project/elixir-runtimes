# Runtimes

Mix tasks for building an Erlang runtime (ERTS) that has NIFs and their native
dependencies statically linked into it, so it can be embedded in an app.

Inspired by Dominic Letz's [elixir-desktop/runtimes](https://github.com/elixir-desktop/runtimes).
On top of that, this project adds:

- **Dependency management:** each package declares its dependencies. They are
  resolved and built in order, and a package is rebuilt only when its source
  revision, build env or makefile changed, or when one of its dependencies was
  rebuilt.
- **A repository of known NIFs:** NIFs (`esqlite`, `egit`) and libraries
  (`openssl`, `libssh2`, `libgit2`) ship ready to use. Projects can add their own.

Supported platforms: `android` (`arm`, `arm64`, `x86_64`). List them with `mix runtimes platforms`.

## Installation

```elixir
def deps do
  [
    {:runtimes, github: "jeanparpaillon/elixir-runtimes", runtime: false}
  ]
end
```

## Usage

The target platform comes from `MIX_TARGET`:

```sh
MIX_TARGET=android mix runtimes.build --archs arm64 esqlite egit
```

This builds the required packages, builds OTP and Elixir, cross-compiles the
requested NIFs (all NIFs supported on the platform if none is given), then links
them into ERTS. The output is written to `_build/<env>/arch-<arch>/staging`.

| Task | Purpose |
|---|---|
| `mix runtimes.build` | Build the full runtime (`--clean` to clean OTP) |
| `mix compile.packages` | Build only the libraries |
| `mix compile.nifs` | Build only the NIFs |
| `mix runtimes platforms` / `packages` | List available platforms / packages |
| `mix runtimes.packages env <arch>` | Print the cross-compilation env |

See `mix help <task>` for options.

## Defining packages

A package is a makefile: `nifs/<name>.mk` for a NIF, `packages/<name>.mk` for a
library. The project's own `nifs/` and `packages/` directories are searched
along with the built-in ones. To change this, set `:nifs_path` / `:packages_path`
in the project config.

Metadata variables:

- `REPO` (required): git repository of the sources, fetched into `deps/<name>`
- `TAG`: git tag or commit (default `master`)
- `DEPS`: package dependencies
- `PLATFORMS`: supported platforms (default: all)
- `EXTRA_RUNTIME`: extra libraries to link into ERTS

The makefile must provide the `build`, `install` and `clean` targets. It runs with
the cross-compilation env (`CC`, `CFLAGS`, …) plus `PLATFORM`, `ARCH`,
`ARCH_NAME`, `ARCH_XCOMP`, `DEPS_PATH`, `BUILD_PATH` and `STAGING_PATH`. A NIF
must install a static archive (`*.a`) into `$(STAGING_PATH)/<name>/`. See
[`priv/nifs/esqlite.mk`](priv/nifs/esqlite.mk) for an example.
