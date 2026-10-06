defmodule Runtimes.Android do
  @moduledoc false
  @behaviour Runtimes.Platform

  import Runtimes.Common

  alias Runtimes.Arch

  @android_abi_version 26

  @archs %{
    "arm" => %Arch{
      xcomp: "arm-android",
      openssl_arch: "android-arm",
      id: "arm",
      abi: @android_abi_version,
      cpu: "arm",
      bin: "armv7a",
      pc: "arm-unknown",
      name: "arm-unknown-linux-androideabi",
      android_name: "androideabi",
      android_type: "armeabi-v7a",
      cflags: "--target=arm-linux-android#{@android_abi_version} -march=armv7-a -mfpu=neon"
    },
    "arm64" => %Arch{
      xcomp: "arm64-android",
      openssl_arch: "android-arm64",
      id: "arm64",
      abi: @android_abi_version,
      cpu: "aarch64",
      bin: "aarch64",
      pc: "aarch64-unknown",
      name: "aarch64-unknown-linux-android",
      android_name: "android",
      android_type: "arm64-v8a",
      cflags: "--target=aarch64-linux-android#{@android_abi_version}"
    },
    "x86_64" => %Arch{
      xcomp: "x86_64-android",
      openssl_arch: "android-x86_64",
      id: "x86_64",
      abi: @android_abi_version,
      cpu: "x86_64",
      bin: "x86_64",
      pc: "x86_64-pc",
      name: "x86_64-pc-linux-android",
      android_name: "android",
      android_type: "x86_64",
      cflags: "--target=x86_64-linux-android#{@android_abi_version}"
    }
  }

  @impl true
  def archs, do: Map.keys(@archs)

  @impl true
  def get_arch(arch) do
    Map.fetch!(@archs, arch)
  end

  @impl true
  def build_env(env, arch) do
    env = Map.new(env)
    path = env["PATH"] || System.get_env("PATH")
    ndk_abi_plat = "#{arch.android_name}#{arch.abi}"

    cflags = (env["CFLAGS"] || "") <> "-Os -fPIC"
    cxxflags = (env["CXXFLAGS"] || "") <> "-Os -fPIC"

    env
    |> Map.merge(%{
      "ANDROID_ABI" => arch.android_type,
      "ANDROID_PLATFORM" => "#{arch.abi}",
      "ANDROID_NDK_HOME" => ndk_home(),
      "PATH" => bin_path() <> ":" <> path,
      "NDK_ABI_PLAT" => ndk_abi_plat,
      "CXX" => toolpath("clang++", arch),
      "CXXFLAGS" => cxxflags,
      "CC" => toolpath("clang", arch),
      "CFLAGS" => cflags,
      "AR" => toolpath("ar", arch),
      "FC" => "",
      "CPP" => "",
      "LD" => toolpath("ld", arch),
      "RANLIB" => toolpath("ranlib", arch),
      "STRIP" => toolpath("strip", arch)
    })
    |> Map.to_list()
  end

  @impl true
  def nif_env(env, arch) do
    ldflags =
      "-v -lc++ -L#{Path.join(ndk_home(), "toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/#{arch.cpu}-linux-android/#{arch.abi}")}"

    env = Map.new(env)

    # CC/CXX are the bare NDK clang, which targets the host unless told otherwise
    env
    |> Map.merge(%{
      "CROSSCOMPILE" => "Android",
      "CFLAGS" => "#{env["CFLAGS"]} #{arch.cflags}",
      "CXXFLAGS" => "#{env["CXXFLAGS"]} #{arch.cflags}",
      "LDFLAGS" => "#{ldflags} #{arch.cflags}"
    })
    |> Map.to_list()
  end

  defp ndk_home() do
    System.get_env("ANDROID_NDK_HOME") ||
      guess_ndk_home() || raise "ANDROID_NDK_HOME is not set"
  end

  defp guess_ndk_home() do
    home = System.get_env("HOME")

    base =
      case :os.type() do
        {:unix, :linux} -> Path.join(home, "Android/Sdk/ndk")
        {:unix, :darwin} -> Path.join(home, "Library/Android/sdk/ndk")
      end

    case File.ls(base) do
      {:ok, versions} -> Path.join(base, List.last(Enum.sort(versions)))
      _ -> raise "No NDK found in #{base}"
    end
  end

  defp bin_path() do
    Path.join(ndk_home(), "/toolchains/llvm/prebuilt/#{host()}/bin")
  end

  def toolpath(tool, arch) do
    real_toolpath(tool, arch) || raise "Tool not found: #{tool} in #{bin_path()}"
  end

  def real_toolpath(tool, arch) do
    [
      tool,
      "llvm-" <> tool,
      "#{arch.cpu}-linux-#{arch.android_name}-#{tool}",
      "#{arch.bin}-linux-#{arch.android_name}-#{tool}"
    ]
    |> Enum.map(fn name -> Path.absname(Path.join(bin_path(), name)) end)
    |> Enum.find(fn name -> File.exists?(name) end)
  end
end
