defmodule Runtimes.Packages do
  @moduledoc """
  Utility functions for handling 3rd party packages.
  """
  alias Runtimes.Package
  alias Runtimes.Packages.Repo

  def all do
    :ok = Repo.ensure_started()

    Repo.all()
    |> Map.values()
  end

  def lookup([], type, platform) do
    all()
    |> Enum.filter(&(&1.type == type and Package.supports_platform?(&1, platform)))
  end

  def lookup(names, type, platform) do
    names
    |> Enum.map(&find!/1)
    |> Enum.map(&Package.ensure_type!(&1, type))
    |> Enum.map(&Package.ensure_platform!(&1, platform))
  end

  @doc """
  Given a list of packages, returns sorted list of packages + their dependencies in topological order.
  """
  def resolve(packages) do
    repo = Repo.all()

    packages
    |> expand(repo, MapSet.new())
    |> sort()
  end

  def find!(name) do
    :ok = Repo.ensure_started()

    if pkg = Repo.find(name) do
      pkg
    else
      Mix.raise("Package #{name} not found")
    end
  end

  # Expand list of packages to include all their dependencies
  defp expand([], _repo, acc), do: acc

  defp expand([pkg | rest], repo, acc) do
    if MapSet.member?(acc, pkg.name) do
      expand(rest, repo, acc)
    else
      expand(pkg.deps ++ rest, repo, MapSet.put(acc, pkg.name))
    end
  end

  # Topological sort: a makefile is emitted after every makefile listed in its
  # `deps` variable. Raises if a dependency is not present in the input list.
  # Returns ordered packages.
  defp sort(packages) do
    graph = Map.new(packages, &{&1.name, &1})

    {sorted, _visited} =
      graph
      |> Map.keys()
      |> Enum.reduce({[], MapSet.new()}, fn name, acc ->
        visit(name, graph, [], acc)
      end)

    Enum.reverse(sorted)
  end

  defp visit(name, graph, path, {sorted, visited} = acc) do
    cond do
      MapSet.member?(visited, name) ->
        acc

      not Map.has_key?(graph, name) ->
        Mix.raise("Package #{hd(path)} depends on unknown package #{name}")

      name in path ->
        Mix.raise(
          "Circular dependency between packages: " <>
            Enum.join(Enum.reverse([name | path]), " -> ")
        )

      true ->
        %Package{} = pkg = graph[name]

        {sorted, visited} =
          Enum.reduce(pkg.deps, {sorted, visited}, fn dep, acc ->
            visit(dep, graph, [name | path], acc)
          end)

        {[pkg | sorted], MapSet.put(visited, name)}
    end
  end
end
