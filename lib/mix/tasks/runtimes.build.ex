defmodule Mix.Tasks.Runtimes.Build do
  @shortdoc "Build OTP runtimes"
  @usage """
  Usage:
    mix runtimes.build --archs <archs> [--clean] [nifs...]

      archs - Comma-separated list of target architectures (see `mix runtimes platforms`).
      clean - Clean the build artifacts before building.
      nifs - Space-separated list of NIFs to build.
  """
  @moduledoc """
  #{@shortdoc}

  Build OTP runtimes together with NIFs and required dependencies.

  #{@usage}
  """
  use Mix.Task

  alias Runtimes
  alias Runtimes.Packages

  import Runtimes.Common

  @switches [archs: :string, clean: :boolean]

  def run(args) do
    {opts, nifs, _} = OptionParser.parse(args, switches: @switches)
    arch_ids = String.split(opts[:archs] || "", ",", trim: true)

    action = if opts[:clean], do: :clean, else: :build

    case Runtimes.find(Mix.target()) do
      {:ok, platform} ->
        packages =
          nifs
          |> Packages.lookup(:nif, platform)
          |> Packages.resolve()

        platform
        |> Runtimes.archs(arch_ids)
        |> Enum.each(&do_action(action, packages, platform, &1))

      :error ->
        Mix.raise("Invalid platform: #{Mix.target()}")
    end
  end

  defp do_action(:build, packages, platform, arch) do
    build(packages, platform, arch)
  end

  defp do_action(:clean, _packages, platform, arch) do
    Mix.shell().info("Cleaning OTP for platform #{platform.name}-#{arch.id}")
    env = platform |> env(arch)
    :ok = otp_mk(["clean"], env)
  end

  defp build(packages, platform, arch) do
    Mix.shell().info("Building ERTS runtime for #{platform.name}-#{arch.id}")

    env = env(platform, arch)
    %{nif: nifs, package: packages} = Enum.group_by(packages, & &1.type)

    Mix.Task.run("compile.packages", ["--archs", arch.id | Enum.map(packages, & &1.name)])

    Mix.shell().info("Pre-compile ERTS for NIFs")
    :ok = otp_mk(["prepare"], add_nif_env(env, otp_nifs(arch)))

    Mix.shell().info("Build elixir")
    :ok = elixir_mk(["build"], env)
    :ok = elixir_mk(["install"], env)

    Mix.Task.rerun("compile.nifs", ["--archs", arch.id | Enum.map(nifs, & &1.name)])

    Mix.shell().info("Assemble ERTS with final NIFs")

    nifs_archives =
      Enum.flat_map(nifs, fn nif ->
        Path.wildcard(Path.join([staging_path(arch.id), nif.name, "*.a"]))
      end)

    nifs_extra =
      nifs
      |> Enum.flat_map(fn package ->
        Enum.map(package.extra_runtime, &"-l#{&1}")
      end)

    env =
      env
      |> add_nif_env(otp_nifs(arch) ++ nifs_archives)
      |> Kernel.++([{"LIBS", Enum.join(nifs_archives ++ nifs_extra, " ")}])

    :ok = otp_mk(["build"], env)

    Mix.shell().info("Install OTP archives in staging dir")
    :ok = otp_mk(["install"], env)

    Mix.shell().info("""
    OTP runtime built for #{platform.name}-#{arch.id}

    OTP archives:
    #{Path.join(staging_path(arch.id), "otp")}

    includes NIFs:
    #{Enum.map_join(nifs, "\n", & &1.name)}
    """)

    :ok
  end

  defp otp_mk(args, env) do
    mk_path = Path.join(scripts_path(), "otp.mk")

    0 =
      Mix.shell().cmd(
        "make -f #{mk_path} #{Enum.join(args, " ")}",
        env: env
      )

    :ok
  end

  defp elixir_mk(args, env) do
    mk_path = Path.join(scripts_path(), "elixir.mk")

    0 =
      Mix.shell().cmd(
        "make -f #{mk_path} #{Enum.join(args, " ")}",
        env: env
      )

    :ok
  end

  defp env(platform, arch) do
    platform
    |> Runtimes.env(arch)
    |> Kernel.++([
      {"MAKEFLAGS", "-j#{System.schedulers_online()} --no-print-directory"},
      {"RELEASE_BEAM", "yes"},
      {"LIBS", openssl_lib(arch.id)},
      {"INSTALL_PROGRAM", install_program()},
      {"BUILD_INDEP_PATH", build_path("indep")}
    ])
  end

  defp add_nif_env(env, nifs) do
    [{"NIFS", Enum.join(nifs, ",")} | env]
  end

  defp openssl_lib(arch_id) do
    Path.join(staging_path(arch_id), "openssl/libcrypto.a")
  end

  defp otp_nifs(arch) do
    build_path = Path.join(build_path(arch.id), "otp")

    [
      "#{build_path}/lib/asn1/priv/lib/#{arch.name}/asn1rt_nif.a",
      "#{build_path}/lib/crypto/priv/lib/#{arch.name}/crypto.a"
    ]
  end
end
