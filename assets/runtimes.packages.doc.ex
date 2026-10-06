defmodule Runtimes.Packages.Doc.Package do
  @moduledoc false
  alias Runtimes.Package

  def module_name(%Package{} = pkg) do
    Module.concat([
      Elixir.Runtimes.Packages,
      Macro.camelize("#{pkg.type}"),
      Macro.camelize(pkg.name)
    ])
  end

  # Makefile path in this repo, so that "View source" links to it
  def source_file(%Package{} = pkg) do
    Path.join([File.cwd!(), "priv", "#{pkg.type}s", Path.basename(pkg.mk)])
  end

  def define(pkg) do
    quote do
      defmodule unquote(module_name(pkg)) do
        @moduledoc unquote(moduledoc(pkg))
      end
    end
  end

  defp moduledoc(pkg) do
    """
    Recipe for building #{pkg.name} with ERTS.

    #{source(pkg)}#{deps(pkg)}
    """
  end

  defp source(pkg) do
    """
    * Source: #{pkg.repo}
    * Version: [`#{pkg.tag}`](#{tree_url(pkg)})
    """
  end

  defp deps(%Package{deps: []}), do: ""

  defp deps(pkg) do
    links =
      Enum.map_join(pkg.deps, ", ", fn name ->
        "`#{inspect(module_name(%Package{name: name, type: :package}))}`"
      end)

    "* Depends on: #{links}"
  end

  # Upstream sources at the pinned tag (GitHub URL layout)
  defp tree_url(pkg) do
    "#{String.trim_trailing(pkg.repo, ".git")}/tree/#{pkg.tag}"
  end
end

defmodule Runtimes.Packages.Doc do
  @moduledoc """
  Creates documentation for the runtimes package.
  """
  require Runtimes.Packages

  alias Runtimes.Packages
  alias Runtimes.Packages.Doc.Package

  Packages.all()
  |> Enum.each(fn pkg ->
    Code.eval_quoted(
      Package.define(pkg),
      [],
      file: Package.source_file(pkg)
    )
  end)
end
