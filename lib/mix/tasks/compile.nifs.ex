defmodule Mix.Tasks.Compile.Nifs do
  @shortdoc "Cross-compile NIFs"
  @moduledoc """
  #{@shortdoc}

  Each NIF build is described in `nifs/*.mk` file

  `build` target is called for each arch

  A package is rebuilt for an arch only when its checked out version (the git
  revision of the mix dep holding its sources), its build env or its makefile
  changed since last build, or when one of its dependencies was rebuilt.

  ## Command line options
  * `--force` - rebuild all packages
  * `--archs` - comma-separated list of architectures to build
  """
  use Mix.Task.Compiler

  import Runtimes.Common

  alias Runtimes
  alias Runtimes.Packages
  alias Runtimes.XComp

  @manifest "compile.nifs"
  @manifest_vsn 1

  @switches [force: :boolean, archs: :string]

  @impl Mix.Task.Compiler
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)
    arch_ids = String.split(opts[:archs] || "", ",", trim: true)

    {:ok, platform} = Runtimes.find(Mix.target())

    packages =
      nifs_path()
      |> Packages.all()
      |> Enum.filter(&Packages.supports_platform?(&1, platform))

    ctx = %XComp.Ctx{
      platform: platform,
      arch_ids: arch_ids,
      env_fun: &Runtimes.nif_env/2,
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
