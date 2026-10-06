defmodule Mix.Tasks.Runtimes do
  @shortdoc "Runtimes utils"
  @usage """
    Usage:
      mix runtimes artifact <arch> - Prints out path to the built runtime
      mix runtimes platforms - List available platforms
      mix runtimes packages - List available packages
      mix runtimes help - Show this help message
  """
  @moduledoc """
  #{@shortdoc}

  #{@usage}
  """
  use Mix.Task

  alias Runtimes
  alias Runtimes.Packages

  def run(["help"]) do
    usage()
  end

  def run(["artifact", arch_id]) do
    platform = Runtimes.find!(Mix.target())
    arch = Runtimes.arch!(platform, arch_id)

    Mix.shell().info(Runtimes.artifact(arch))
  rescue
    e in ArgumentError ->
      Mix.raise("Error: #{e.message}")
  end

  def run(["platforms"]) do
    Runtimes.platforms()
    |> Enum.map_join("\n", &pp_platform/1)
    |> Mix.shell().info()
  end

  def run(["packages"]) do
    Packages.all()
    |> Enum.map_join("\n", &pp_package/1)
    |> Mix.shell().info()
  end

  def run(_) do
    usage()
  end

  defp usage do
    Mix.shell().info(@usage)
  end

  defp pp_package(package) do
    """
    Name: #{package.name}
    Source Dir: #{package.source_dir}
    Repo: #{package.repo}
    Version: #{package.tag}
    """ <>
      if package.platforms != [] do
        "Platforms: #{Enum.join(package.platforms, ", ")}\n"
      else
        "Platforms: *\n"
      end <>
      if package.deps != [] do
        "Deps: #{Enum.join(package.deps, ", ")}\n"
      else
        ""
      end
  end

  defp pp_platform(%Runtimes.Platform{} = platform) do
    """
    Platform: #{platform.name}
       Archs: #{Enum.join(platform.archs, ", ")}
    """
  end
end
