defmodule Runtimes.Platform do
  @moduledoc """
  Describe a target platform

  A platform is implemented by a module adopting this behaviour, registered in
  `Runtimes`.
  """

  defstruct name: nil, archs: [], module: nil

  @type t :: %__MODULE__{
          name: atom() | nil,
          archs: list(),
          module: module() | nil
        }

  @doc """
  Returns the IDs of the supported archs
  """
  @callback archs() :: [String.t()]

  @doc """
  Returns the config of the given arch
  """
  @callback get_arch(arch_id :: String.t()) :: Runtimes.Arch.t()

  @doc """
  Adds the cross-compilation toolchain to the given env

  Used to build packages and OTP, and as the base of `c:nif_env/2`.
  """
  @callback build_env(Runtimes.env(), Runtimes.Arch.t()) :: Runtimes.env()

  @doc """
  Adds the NIF specific settings to the given env

  Receives the output of `c:build_env/2`.
  """
  @callback nif_env(Runtimes.env(), Runtimes.Arch.t()) :: Runtimes.env()

  def create(name, module) do
    %__MODULE__{
      name: name,
      archs: module.archs(),
      module: module
    }
  end
end
