defmodule Mix.Tasks.Runtimes.Packages do
  @shortdoc "Runtime packages actions"
  @usage """
    Usage:
      mix runtimes.packages fetch - Fetch all runtime packages
      mix runtimes.packages env <arch> - prints cross-compilation for the targeted arch
      mix runtimes.packages nif_env <arch> - prints NIF env for the targeted arch
      mix runtimes.packages help - Show this help message
  """
  @moduledoc """
  Provides actions for managing runtime packages defined in the project.

  #{@usage}
  """
  use Mix.Task

  alias Runtimes
  alias Runtimes.Package
  alias Runtimes.Packages

  top_dir = Path.dirname(Mix.Project.project_file())
  @otp_mk Path.join(top_dir, "scripts/otp.mk")
  @elixir_mk Path.join(top_dir, "scripts/elixir.mk")

  def run(args) do
    platform = Runtimes.find!(Mix.target())

    case args do
      [] ->
        usage()

      ["help"] ->
        usage()

      ["fetch"] ->
        fetch_packages(platform)

      ["env", arch] ->
        env(arch)

      ["nif_env", arch] ->
        nif_env(arch)

      _ ->
        Mix.raise("Unknown action: #{Enum.join(args, ", ")}")
    end
  end

  defp usage do
    Mix.shell().info(@usage)
  end

  defp env(arch_id) do
    {:ok, platform} = Runtimes.find(Mix.target())
    env = Runtimes.env(platform, arch_id)
    pp_env(env)
  end

  defp nif_env(arch_id) do
    {:ok, platform} = Runtimes.find(Mix.target())
    env = Runtimes.nif_env(platform, arch_id)
    pp_env(env)
  end

  defp fetch_packages(platform) do
    packages =
      []
      |> Packages.lookup(:package, platform)
      |> Packages.resolve()
      |> Kernel.++([
        Package.create(@otp_mk),
        Package.create(@elixir_mk)
      ])

    Enum.each(packages, &fetch_package(&1))
  end

  defp fetch_package(package) do
    Mix.shell().info("* #{package.name} (git)")
    Mix.shell().info("  checked out #{package.tag}")

    if File.exists?(package.source_dir) do
      update_package_repo(package)
    else
      clone_package_repo(package)
    end

    Mix.shell().info("  ok")
  end

  defp clone_package_repo(package) do
    0 =
      Mix.shell().cmd("git clone --branch \"#{package.tag}\" --depth 1 \
      \"#{package.repo}\" \"#{package.source_dir}\"",
        quiet: true
      )
  end

  defp update_package_repo(package) do
    0 =
      Mix.shell().cmd(
        "git -C \"#{package.source_dir}\" fetch --depth 1 origin \"refs/tags/#{package.tag}:refs/tags/#{package.tag}\""
      )

    0 =
      Mix.shell().cmd("git -C \"#{package.source_dir}\" checkout --detach \"#{package.tag}\"",
        quiet: true
      )
  end

  defp pp_env(env) do
    Enum.each(env, fn {key, value} -> Mix.shell().info("#{key}=#{value}") end)
  end
end
