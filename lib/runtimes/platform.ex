defmodule Runtimes.Platform do
  @moduledoc """
  Describe a target platform
  """

  defstruct name: nil, archs: [], module: nil

  @type t :: %__MODULE__{
          name: String.t() | nil,
          archs: list(),
          module: module() | nil
        }
end
