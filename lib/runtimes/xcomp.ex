defmodule Runtimes.XComp do
  @moduledoc """
  Cross compilation utilities for runtime
  """
  alias Runtimes
  alias Runtimes.Packages.Package
  alias Runtimes.XComp.Ctx

  import Runtimes.Common

  @doc """
  Build the given packages for the specified cross compilation context.
  """
  @spec build([Package.t()], Ctx.t()) :: {:ok | :noop, []}
  def build(packages, ctx) do
    manifest =
      if ctx.force do
        %{}
      else
        read_manifest(ctx.manifest_path, ctx.manifest_vsn)
      end

    archs = Runtimes.archs(ctx.platform, ctx.arch_ids)

    {status, _manifest} =
      archs
      |> Enum.reduce({:noop, manifest}, fn arch, {status, manifest} ->
        env = ctx.env_fun.(ctx.platform, arch)

        {status, manifest} =
          case build_arch(packages, arch.id, manifest, ctx.manifest_vsn, ctx.manifest_path, env) do
            {:ok, manifest} -> {:ok, manifest}
            {:noop, manifest} -> {status, manifest}
          end

        :ok = install_arch(packages, arch.id, env)
        {status, manifest}
      end)

    {status, []}
  end

  defp build_arch(packages, arch_id, manifest, manifest_vsn, manifest_path, env) do
    {rebuilt, manifest} =
      packages
      |> Enum.reduce({MapSet.new(), manifest}, fn pkg, {rebuilt, manifest} ->
        entry = manifest_entry(pkg, arch_id, env)
        key = {arch_id, pkg.name}

        if stale?(pkg, manifest[key], entry, rebuilt) do
          :ok = build_package(pkg, arch_id, env)
          # Written after each package, so a failed build keeps earlier progress
          manifest = Map.put(manifest, key, entry)
          write_manifest(manifest, manifest_vsn, manifest_path)
          {MapSet.put(rebuilt, pkg.name), manifest}
        else
          {rebuilt, manifest}
        end
      end)

    if MapSet.size(rebuilt) == 0, do: {:noop, manifest}, else: {:ok, manifest}
  end

  defp build_package(package, arch_id, env) do
    source_dir = ensure_clean_source(package, arch_id, env)

    case Mix.shell().cmd("make -C #{source_dir} -f #{package.mk} build", env: env) do
      0 -> :ok
      status -> Mix.raise("Failed to build #{package.name} for arch #{arch_id} (exit #{status})")
    end
  end

  defp ensure_clean_source(package, arch_id, env) do
    source_dir =
      if package.type == :nif do
        # mix compiles NIF in the source directory, copy sources
        source_dir = Path.join(build_path(arch_id), package.name)
        File.rm_rf!(source_dir)
        File.cp_r!(package.source_dir, source_dir)

        source_dir
      else
        package.source_dir
      end

    Mix.shell().cmd("make -C #{source_dir} -f #{package.mk} clean", env: env, quiet: true)

    source_dir
  end

  defp install_arch(packages, arch_id, env) do
    packages
    |> Enum.each(fn package ->
      Mix.shell().info("Installing #{package.name} for target #{Mix.target()} / arch #{arch_id}")

      case Mix.shell().cmd("make -C #{package.source_dir} -f #{package.mk} install", env: env) do
        0 ->
          :ok

        status ->
          Mix.raise("Failed to install #{package.name} for arch #{arch_id} (exit #{status})")
      end
    end)
  end

  defp read_manifest(path, vsn) do
    with {:ok, bin} <- File.read(path),
         {^vsn, entries} <- :erlang.binary_to_term(bin) do
      entries
    else
      _ -> %{}
    end
  rescue
    ArgumentError -> %{}
  end

  defp write_manifest(entries, vsn, path) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, :erlang.term_to_binary({vsn, entries}))
  end

  defp stale?(pkg, previous, entry, rebuilt) do
    previous != entry or Enum.any?(pkg.deps, &MapSet.member?(rebuilt, &1))
  end

  defp manifest_entry(package, arch_id, env) do
    %{
      name: package.name,
      arch: arch_id,
      version: checked_out_version(package),
      env: Map.new(env),
      mk: :erlang.md5(File.read!(package.mk))
    }
  end

  defp checked_out_version(package) do
    case System.cmd("git", ["-C", package.source_dir, "rev-parse", "HEAD"],
           stderr_to_stdout: true
         ) do
      {out, 0} -> String.trim(out)
      {out, _} -> Mix.raise("Failed to read checked out version of #{package.name}:\n#{out}")
    end
  end
end
