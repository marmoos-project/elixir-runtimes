defmodule Runtimes.Packages.Repo do
  @moduledoc false

  alias Runtimes.Package

  import Runtimes.Common

  def ensure_started(args \\ []) do
    nifs_path = Keyword.get(args, :nifs_path, nifs_path())
    packages_path = Keyword.get(args, :packages_path, packages_path())

    case Agent.start_link(
           fn -> init(nifs_path, packages_path) end,
           name: __MODULE__
         ) do
      {:ok, _pid} ->
        load()

      {:error, {:already_started, _pid}} ->
        ensure_loaded()

      {:error, reason} ->
        Mix.raise("Failed to start Packages Repo: #{inspect(reason)}")
    end
  end

  def stop do
    Agent.stop(__MODULE__)
  end

  def all do
    Agent.get(__MODULE__, & &1.packages)
  end

  def add(package) do
    Agent.update(__MODULE__, fn state ->
      put_in(state[:packages][package.name], package)
    end)
  end

  def find(name) do
    Agent.get(__MODULE__, fn state ->
      get_in(state[:packages][name])
    end)
  end

  defp loaded? do
    Agent.get(__MODULE__, fn state -> state[:loaded?] end)
  end

  defp init(nifs_path, packages_path) do
    %{nifs_path: nifs_path, packages_path: packages_path, packages: %{}, loaded?: false}
  end

  defp get(key) do
    Agent.get(__MODULE__, fn state -> Map.get(state, key) end)
  end

  defp load do
    nifs =
      get(:nifs_path)
      |> Enum.flat_map(fn dir ->
        dir
        |> Path.join("*.mk")
        |> Path.wildcard()
      end)
      |> Enum.map(&Package.create(&1, :nif))

    packages =
      get(:packages_path)
      |> Enum.flat_map(fn dir ->
        dir
        |> Path.join("*.mk")
        |> Path.wildcard()
      end)
      |> Enum.map(&Package.create(&1, :package))

    (nifs ++ packages)
    |> Enum.each(&add(&1))

    Agent.update(__MODULE__, fn state ->
      put_in(state[:loaded?], true)
    end)

    :ok
  end

  defp ensure_loaded do
    if loaded?(), do: :ok, else: load()
  end
end
