defmodule Mix.Tasks.Compile.Packages do
  @shortdoc "Build 3rd party packages for runtime"
  @usage """
  Usage:
  mix compile.packages --archs <archs> [--force] [packages...]

    archs - Comma-separated list of target architectures.
    force - Rebuild all packages.
    packages - Space-separated list of packages to build.
  """
  @moduledoc """
  #{@shortdoc}

  Each package build is described in `packages/*.mk` file

  `build` target is called for each arch

  A package is rebuilt for an arch only when its checked out version (the git
  revision of the mix dep holding its sources), its build env or its makefile
  changed since last build, or when one of its dependencies was rebuilt.

  #{@usage}
  """
  use Mix.Task.Compiler

  alias Runtimes
  alias Runtimes.Packages
  alias Runtimes.XComp

  @manifest "compile.packages"
  @manifest_vsn 1

  @switches [force: :boolean, archs: :string]

  @impl Mix.Task.Compiler
  def run(args) do
    {opts, packages, _} = OptionParser.parse(args, switches: @switches)
    arch_ids = String.split(opts[:archs] || "", ",", trim: true)

    {:ok, platform} = Runtimes.find(Mix.target())

    packages =
      packages
      |> Packages.lookup(:package, platform)
      |> Packages.resolve()

    ctx = %XComp.Ctx{
      platform: platform,
      arch_ids: arch_ids,
      env_fun: &Runtimes.env/2,
      manifest_path: manifest(),
      manifest_vsn: @manifest_vsn,
      force: opts[:force] || false
    }

    XComp.build(packages, ctx)
  end

  @impl Mix.Task.Compiler
  def manifests, do: [manifest()]

  @impl Mix.Task.Compiler
  def clean, do: File.rm(manifest())

  defp manifest, do: Path.join(Mix.Project.manifest_path(), @manifest)
end
