defmodule Runtimes.Packages do
  @moduledoc """
  Utility functions for handling 3rd party packages.
  """
  alias Runtimes.Package

  @doc """
  Read makefile and create package structs.
  """
  def create(makefile) do
    name = Path.basename(makefile, ".mk")
    source_dir = Path.join(Mix.Project.deps_path(), name)

    %Package{
      name: name,
      mk: makefile,
      source_dir: source_dir
    }
    |> read_deps()
    |> read_repo()
    |> read_platforms()
  end

  @doc """
  Returns true if the package supports the given platform.
  """
  def supports_platform?(package, platform) do
    package.platforms == [] or platform.name in package.platforms
  end

  def all(dirs) do
    dirs
    |> load()
    |> sort()
  end

  @doc """
  Load packages repositories
  """
  def load(dirs) do
    dirs
    |> Enum.flat_map(fn dir ->
      dir
      |> Path.join("*.mk")
      |> Path.wildcard()
    end)
    |> Enum.map(&create(&1))
    |> sort()
  end

  def checked_out?(%Package{name: name}) do
    repo_path = Path.join("deps", name)
    File.exists?(repo_path)
  end

  @doc """
  Find a package by name and include its dependencies, transitively.
  """
  def find(packages, nil), do: packages

  def find(packages, package_name) do
    by_name = Map.new(packages, &{&1.name, &1})

    unless Map.has_key?(by_name, package_name) do
      Mix.raise("Unknown package #{package_name}")
    end

    names = collect_deps([package_name], by_name, MapSet.new())
    Enum.filter(packages, &MapSet.member?(names, &1.name))
  end

  # Dependencies missing from `by_name` are skipped here; sort/1 reports them.
  defp collect_deps([], _by_name, acc), do: acc

  defp collect_deps([name | rest], by_name, acc) do
    cond do
      MapSet.member?(acc, name) ->
        collect_deps(rest, by_name, acc)

      pkg = by_name[name] ->
        collect_deps(pkg.deps ++ rest, by_name, MapSet.put(acc, name))

      true ->
        collect_deps(rest, by_name, acc)
    end
  end

  # Topological sort: a makefile is emitted after every makefile listed in its
  # `deps` variable. Raises if a dependency is not present in the input list.
  # Returns ordered packages.
  def sort(packages) do
    graph =
      Map.new(packages, &{&1.name, &1})

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

  defp read_deps(%Package{} = package) do
    deps =
      package.mk
      |> makefile_var("deps")
      |> String.split()

    %Package{package | deps: deps}
  end

  defp read_platforms(%Package{} = package) do
    platforms =
      package.mk
      |> makefile_var("PLATFORMS")
      |> String.split()

    %Package{package | platforms: platforms}
  end

  defp read_repo(%Package{} = package) do
    repo =
      package.mk
      |> makefile_var("REPO")
      |> String.trim()

    tag =
      package.mk
      |> makefile_var("TAG")
      |> String.trim()

    set_repo(package, repo, tag)
  end

  defp set_repo(%Package{} = package, "", _) do
    deps = Mix.Project.config()[:deps]

    {scm, vsn} =
      case Enum.find(deps, fn
             {name, _opts} -> "#{name}" == package.name
           end) do
        nil -> nil
        dep -> get_dep_scm(dep)
      end

    %Package{package | repo: scm, tag: vsn}
  end

  defp set_repo(%Package{} = package, repo, tag) do
    %Package{package | repo: repo, tag: tag}
  end

  defp get_dep_scm({_, vsn}) when is_binary(vsn) do
    {:hex, vsn}
  end

  defp get_dep_scm({_, opts}) when is_list(opts) do
    cond do
      opts[:github] != nil ->
        {"https://github.com/#{opts[:github]}", opts[:tag] || "master"}

      opts[:git] != nil ->
        {opts[:git], opts[:tag] || "master"}

      true ->
        nil
    end
  end

  defp makefile_var(makefile, name) do
    printer = "@echo $(#{name})"

    {out, 0} =
      System.cmd(
        "make",
        ["-f", makefile, "-s", "--eval=print:; #{printer}", "print"],
        stderr_to_stdout: true
      )

    out
  end
end
