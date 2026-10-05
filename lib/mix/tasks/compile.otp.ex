defmodule Mix.Tasks.Compile.Otp do
  @shortdoc "Cross compile OTP"
  @moduledoc """
  #{@shortdoc}

  Cross-compile OTP together with NIFs
  """
  use Mix.Task

  alias Runtimes
  alias Runtimes.Packages

  import Runtimes.Common

  # @manifest "compile.otp"
  # @manifest_vsn 1

  @switches [force: :boolean, archs: :string, clean: :boolean]

  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches)
    arch_ids = String.split(opts[:archs] || "", ",", trim: true)

    action = if opts[:clean], do: :clean, else: :build

    case Runtimes.find(Mix.target()) do
      {:ok, platform} ->
        platform
        |> Runtimes.archs(arch_ids)
        |> Enum.each(&do_action(action, platform, &1))

      :error ->
        Mix.raise("Invalid platform: #{Mix.target()}")
    end
  end

  defp do_action(:build, platform, arch) do
    build(platform, arch)
  end

  defp do_action(:clean, platform, arch) do
    Mix.shell().info("Cleaning OTP for platform #{platform.name}-#{arch.id}")
    env = platform |> env(arch)
    :ok = otp_mk(["clean"], env)
  end

  defp build(platform, arch) do
    Mix.shell().info("Building OTP runtime for #{platform.name}-#{arch.id}")

    env = env(platform, arch)

    Mix.Task.run("compile.packages", ["--archs", arch.id])

    Mix.shell().info("Pre-compile OTP for NIFs")
    :ok = otp_mk(["prepare"], add_nif_env(env, otp_nifs(arch)))

    Mix.shell().info("Build elixir")
    :ok = elixir_mk(["build"], env)
    :ok = elixir_mk(["install"], env)

    Mix.Task.rerun("compile.nifs", ["--archs", arch.id])

    Mix.shell().info("Build OTP with final NIFs")
    extra_nifs = extra_nifs(arch)

    env =
      env
      |> add_nif_env(otp_nifs(arch) ++ extra_nifs)
      |> List.keystore("LIBS", 0, {"LIBS", final_libs(arch)})

    :ok = otp_mk(["build"], env)

    Mix.shell().info("Install OTP archives in staging dir")
    :ok = otp_mk(["install"], env)

    Mix.shell().info("""
    OTP runtime built for #{platform.name}-#{arch.id}

    OTP archives:
    #{Path.join(staging_path(arch.id), "otp")}

    with NIFs:
    #{extra_nifs |> Enum.map(&Path.relative_to(&1, staging_path(arch.id))) |> Enum.join("\n")}
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

  # STATIC_NIF_LIBS precede LIBS on the ERTS link line, so the packages the NIFs
  # build on go here: every staged package archive, dependents before their
  # deps (Packages.find/1 sorts deps first). Only for the final build: the
  # archives don't exist yet at `prepare`.
  defp final_libs(arch) do
    staging_path = staging_path(arch.id)

    packages_path()
    |> Packages.all()
    |> Enum.reverse()
    |> Enum.flat_map(&Path.wildcard(Path.join([staging_path, &1.name, "*.a"])))
    |> Enum.join(" ")
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

  defp extra_nifs(arch) do
    staging_path = staging_path(arch.id)

    nifs_path()
    |> Packages.all()
    |> Enum.flat_map(fn nif ->
      Path.wildcard(Path.join(staging_path, "#{nif.name}/*.a"))
    end)
  end
end
