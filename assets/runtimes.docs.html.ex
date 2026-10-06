defmodule Runtimes.Docs.Html do
  @moduledoc false
  # ExDoc HTML formatter, without the leading "." ExDoc puts on module names
  # nested with `:nest_modules_by_prefix`.
  @behaviour ExDoc.Formatter

  @impl true
  def run(config, nodes, extras) do
    nodes = Enum.map(nodes, &strip_nested_title/1)
    ExDoc.Formatter.HTML.run(config, nodes, extras)
  end

  @impl true
  defdelegate autolink_options, to: ExDoc.Formatter.HTML

  @nif_prefix "Runtimes.Packages.Nif."
  @package_prefix "Runtimes.Packages.Package."

  defp strip_nested_title(%{title: @nif_prefix <> title} = node) do
    %{node | title: title}
  end

  defp strip_nested_title(%{title: @package_prefix <> title} = node) do
    %{node | title: title}
  end

  defp strip_nested_title(node),
    do: node
end
