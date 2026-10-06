defmodule Runtimes.Arch do
  @moduledoc """
  Target arch config, as returned by `c:Runtimes.Platform.get_arch/1`

  Common fields:

  - `id`: arch ID given on the command line (`--archs`)
  - `name`: target triple OTP builds for, e.g. `aarch64-unknown-linux-android`
  - `xcomp`: selects OTP's `xcomp/erl-xcomp-<xcomp>.conf`
  - `openssl_arch`: OpenSSL `Configure` target
  - `cpu`: CPU name, as used in toolchain paths and triples
  - `cflags`: extra compiler flags for the target

  Android fields:

  - `abi`: minimum Android API level
  - `bin`: CPU prefix of the NDK tool names
  - `pc`: CPU-vendor part of the GNU triple
  - `android_name`: OS part of the NDK triple (`android`, `androideabi`)
  - `android_type`: Android ABI name, e.g. `arm64-v8a`
  """

  @enforce_keys [:id, :name, :xcomp]
  defstruct id: nil,
            name: nil,
            xcomp: nil,
            openssl_arch: nil,
            cpu: nil,
            cflags: "",
            abi: nil,
            bin: nil,
            pc: nil,
            android_name: nil,
            android_type: nil

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          xcomp: String.t(),
          openssl_arch: String.t() | nil,
          cpu: String.t() | nil,
          cflags: String.t(),
          abi: pos_integer() | nil,
          bin: String.t() | nil,
          pc: String.t() | nil,
          android_name: String.t() | nil,
          android_type: String.t() | nil
        }
end
