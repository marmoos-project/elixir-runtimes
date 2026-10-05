defmodule Runtimes.XComp.Ctx do
  @moduledoc """
  Context for cross compilation.
  """
  alias Runtimes
  alias Runtimes.Platform

  defstruct platform: nil,
            arch_ids: [],
            env_fun: &Runtimes.env/2,
            force: false,
            manifest_path: nil,
            manifest_vsn: 1

  @type t :: %__MODULE__{
          platform: Platform.t() | nil,
          arch_ids: [String.t()],
          env_fun: (Platform.t() | nil, String.t() -> list()),
          force: boolean(),
          manifest_path: String.t() | nil,
          manifest_vsn: integer()
        }
end
