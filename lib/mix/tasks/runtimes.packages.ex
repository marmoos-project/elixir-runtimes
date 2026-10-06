defmodule Mix.Tasks.Runtimes.Packages do
  @shortdoc "Runtime packages actions"
  @usage """
    Usage:
      mix runtimes.packages fetch - Fetch sources of OTP, Elixir, NIFs and packages
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

  import Runtimes.Common

  def run(args) do
    case args do
      [] ->
        usage()

      ["help"] ->
        usage()

      ["fetch"] ->
        fetch_packages(platform!())

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
    env = Runtimes.env(platform!(), arch_id)
    pp_env(env)
  end

  defp nif_env(arch_id) do
    env = Runtimes.nif_env(platform!(), arch_id)
    pp_env(env)
  end

  defp platform! do
    case Runtimes.find(Mix.target()) do
      {:ok, platform} -> platform
      :error -> Mix.raise("Invalid platform: #{Mix.target()}")
    end
  end

  defp fetch_packages(platform) do
    packages =
      (Packages.lookup([], :package, platform) ++ Packages.lookup([], :nif, platform))
      |> Packages.resolve()
      |> Kernel.++([
        Package.create(Path.join(scripts_path(), "otp.mk")),
        Package.create(Path.join(scripts_path(), "elixir.mk"))
      ])

    Enum.each(packages, &fetch_package/1)
  end

  # Shallow fetch of TAG, which may be a tag, a branch or a commit hash
  defp fetch_package(package) do
    Mix.shell().info("* #{package.name} (#{package.repo} - #{package.tag})")

    unless File.dir?(Path.join(package.source_dir, ".git")) do
      File.mkdir_p!(package.source_dir)
      git!(package, ["init", "--quiet"])
      git!(package, ["remote", "add", "origin", package.repo])
    end

    git!(package, ["fetch", "--quiet", "--depth", "1", "origin", package.tag])
    git!(package, ["checkout", "--quiet", "--detach", "FETCH_HEAD"])
  end

  defp git!(package, args) do
    case System.cmd("git", ["-C", package.source_dir | args], stderr_to_stdout: true) do
      {_, 0} ->
        :ok

      {out, status} ->
        Mix.raise(
          "Fetching #{package.name} failed: git #{Enum.join(args, " ")} exited with #{status}\n#{out}"
        )
    end
  end

  defp pp_env(env) do
    Enum.each(env, fn {key, value} -> Mix.shell().info("#{key}=#{value}") end)
  end
end
