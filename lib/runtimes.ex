defmodule Runtimes do
  @moduledoc """
  Utilities for cross compiling
  """
  import Runtimes.Common

  alias Runtimes.Platform

  @type env :: list({String.t(), String.t()})

  @platforms %{
    android: Runtimes.Android
  }

  def platforms do
    @platforms
    |> Enum.map(fn {name, module} ->
      Platform.create(name, module)
    end)
  end

  @doc """
  Returns default packages path
  """
  def packages_path do
    Runtimes.Common.default_packages_path()
  end

  @doc """
  Returns the runtime struct for the given target.

  ## Examples

      iex> Runtimes.find(:android)
      {:ok, %Runtimes.Platform{name: :android, archs: ["arm", "arm64", "x86_64"], module: Runtimes.Android}}

      iex> Runtimes.find(:unknown)
      :error
  """
  def find(name) do
    @platforms
    |> Map.get(name)
    |> case do
      nil ->
        :error

      module ->
        {:ok, Platform.create(name, module)}
    end
  end

  def find!(name) do
    case find(name) do
      {:ok, platform} -> platform
      :error -> raise ArgumentError, "Unknown platform `#{name}`"
    end
  end

  @doc """
  Returns all available arch configs for given platform
  """
  @spec archs(Platform.t(), list(String.t())) :: list(map())
  def archs(%Platform{} = platform, arch_ids) do
    ids = if arch_ids == [], do: platform.archs, else: arch_ids

    Enum.map(ids, fn arch_id ->
      platform.module.get_arch(arch_id)
    end)
  end

  @doc """
  Returns arch config for the given arch ID
  """
  @spec arch!(Platform.t(), String.t() | map()) :: map()
  def arch!(%Platform{} = platform, arch_id) when is_binary(arch_id) do
    if arch_id in platform.archs do
      platform.module.get_arch(arch_id)
    else
      raise ArgumentError, "Unknown arch ID #{arch_id} for platform #{platform.name}"
    end
  end

  def arch!(_platform, %{} = arch), do: arch

  @doc """
  Build env for given platform and arch
  """
  @spec env(Platform.t(), String.t() | map()) :: env()
  def env(%Platform{} = platform, arch) do
    arch = arch!(platform, arch)

    base_env(platform, arch)
    |> Kernel.++([{"HOST", host()}])
    |> platform.module.build_env(arch)
  end

  def nif_env(%Platform{} = platform, arch) do
    arch = arch!(platform, arch)

    env =
      platform
      |> base_env(arch)
      |> Map.new()
      |> Map.merge(%{"HOST" => arch.name})

    mix_home = Path.join(build_path("indep"), "mix")

    path =
      [
        Path.join(build_path("indep"), "elixir/bin"),
        System.get_env("PATH")
      ]
      |> Enum.join(":")

    erts_version = erts_version(arch.id)

    erts_include_dir =
      Path.join(
        build_path(arch.id),
        "otp/release/#{arch.name}/erts-#{erts_version}/include"
      )

    env
    |> Map.merge(%{
      "PATH" => path,
      "ERLANG_PATH" => erts_include_dir,
      "ERTS_INCLUDE_DIR" => erts_include_dir,
      "STATIC_ERLANG_NIF" => "yes",
      "MIX_ENV" => "prod",
      "MIX_HOME" => mix_home
    })
    |> Map.to_list()
    |> platform.module.build_env(arch)
    |> platform.module.nif_env(arch)
  end

  defp base_env(platform, arch) do
    [
      {"PLATFORM", "#{platform.name}"},
      {"ARCH", arch[:id]},
      {"ARCH_NAME", arch[:name]},
      {"ARCH_XCOMP", arch[:xcomp]},
      {"DEPS_PATH", Mix.Project.deps_path()},
      {"BUILD_PATH", build_path(arch.id)},
      {"STAGING_PATH", staging_path(arch.id)}
    ]
  end
end
