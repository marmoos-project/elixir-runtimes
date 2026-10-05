defmodule Runtimes.Package do
  @moduledoc """
  Describe a 3rd party package and its metadata.
  """
  defstruct mk: nil,
            name: nil,
            source_dir: nil,
            deps: [],
            repo: nil,
            tag: nil,
            archs: [],
            platforms: []

  @type t :: %__MODULE__{
          mk: String.t() | nil,
          name: String.t() | nil,
          source_dir: String.t() | nil,
          deps: [String.t()],
          repo: String.t() | nil,
          tag: String.t() | nil,
          archs: [String.t()],
          platforms: [String.t()]
        }
end
