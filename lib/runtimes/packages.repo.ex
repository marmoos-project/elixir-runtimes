defmodule Runtimes.Packages.Repo do
  @moduledoc false

  alias Runtimes.Package

  import Runtimes.Common

  def ensure_started do
    case Agent.start_link(&init/0, name: __MODULE__) do
      {:ok, _pid} ->
        load()

      {:error, {:already_started, _pid}} ->
        ensure_loaded()

      {:error, reason} ->
        Mix.raise("Failed to start Packages Repo: #{inspect(reason)}")
    end
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

  def loaded? do
    Agent.get(__MODULE__, fn state -> state[:loaded?] end)
  end

  defp init do
    %{packages: %{}, loaded?: false}
  end

  defp load do
    nifs =
      nifs_path()
      |> Enum.flat_map(fn dir ->
        dir
        |> Path.join("*.mk")
        |> Path.wildcard()
      end)
      |> Enum.map(&Package.create(&1, :nif))

    packages =
      packages_path()
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
    unless loaded?() do
      load()
    end
  end
end
