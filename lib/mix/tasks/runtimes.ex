defmodule Mix.Tasks.Runtimes do
  @shortdoc "Runtimes utils"
  @moduledoc """
  #{@shortdoc}
  """
  use Mix.Task

  alias Runtimes

  def run(["platforms"]) do
    Runtimes.platforms()
    |> Enum.map(&pp_platform/1)
    |> Enum.join("\n")
    |> Mix.shell().info()
  end

  defp pp_platform(%Runtimes.Platform{} = platform) do
    """
    Platform: #{platform.name}
       Archs: #{Enum.join(platform.archs, ", ")}
    """
  end
end
