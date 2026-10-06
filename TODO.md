# TODO

## Cache prepared OTP as a downloadable artifact

### Goal

Building OTP is the slowest step of `mix runtimes.build`. Only the **prepare**
step (`otp.mk prepare`) gives a result that does not depend on the NIFs a
project picks:

```
compile.packages ──► otp prepare ──► elixir ──► compile.nifs ──► otp build ──► otp install
                     (cacheable)                (needs ERTS       (relinks with the
                                                 headers)          project's NIFs)
```

Prepare runs `otp_build setup/boot -a/release -a` with only the built-in static
NIFs (`asn1rt_nif.a`, `crypto.a`). It produces:

- `release/<arch.name>/erts-<vsn>/include`, which NIFs compile against
  (`ERTS_INCLUDE_DIR` in `Runtimes.nif_env/2`);
- `erts/vsn.mk`, read by `Runtimes.Common.erts_version/1`;
- the whole object tree, which the final `build` step reconfigures and relinks
  with the project's NIF archives.

So the artifact is the prepared OTP build tree for one platform/arch. With it,
a project can skip both the OTP fetch and the prepare step.

Artifact name: `otp-<platform>-<arch>.zip`, e.g. `otp-android-arm64.zip`.

### 1. Artifact content

Paths are relative to `build_path(arch)` (`_build/<target>_<env>/arch-<arch>/`):

- [ ] `otp/`: the prepared tree, **without `.git/`**. `otp.mk clean` already
      tolerates a missing `.git` (`|| true`). Check whether the final build needs
      anything from git.
- [ ] `.stamp_otp_prepare`
- [ ] `openssl/`: the openssl install prefix. Configure uses it through
      `--with-ssl=$(BUILD_PATH)/openssl`, and `crypto.a` was built against its
      headers. The final build reruns configure, so it has to be there.
- [ ] `otp-artifact.json`: the manifest, see §2.

Measured locally: `arch-arm/otp` is about 700 MB after a full build, about
300 MB for arm64. Measure the size after prepare only and decide whether to
prune it (docs, `*_st.a`/`*_r.a`, host-side test files). The final build needs
the object files, so those stay.

### 2. Compatibility key and manifest

A cached tree is only valid when everything that went into prepare matches.
The cache key is one hash over:

- the **normalized build env**: the env `otp.mk prepare` runs with
  (`env(platform, arch)` + `NIFS`), sorted by key;
- `otp.mk`, which holds `TAG` and `otp_build_opts`;
- `elixir.mk`;
- `openssl.mk`.

The three makefiles cover the source versions and build options. The env covers
the platform, arch, toolchain and ABI.

- [ ] Normalization: the key has to be the same on any machine for the same
      inputs, so drop or replace what is machine-local:
  - replace the project paths (`BUILD_PATH`, `DEPS_PATH`, `STAGING_PATH`,
    `BUILD_INDEP_PATH`, and the `LIBS`/`NIFS` entries under them) with
    placeholders such as `$BUILD_PATH`;
  - drop `PATH` and `MAKEFLAGS` (`-j<cores>`);
  - replace the NDK root in `ANDROID_NDK_HOME`, `CC`, `AR`, … with `$NDK`.
    Because the NDK version is part of that path (`ndk/<version>`), take the
    version from `source.properties` (`Pkg.Revision`) and add it to the hashed
    env, so an NDK change still invalidates the cache.
  - `HOST` (linux-x86_64 / darwin-x86_64) stays in. `boot -a` builds host
    bootstrap binaries, so a tree built on Linux is unusable on macOS.
- [ ] Unit-test the normalization: the same inputs under two different project
      dirs and NDK install locations must give the same hash.
- [ ] `otp-artifact.json` holds the hash plus, for diagnostics only, the
      normalized env and the makefile hashes. On a mismatch, the message can then
      say what differs.
- [ ] The key is computed locally before downloading. Put it in a small index
      (or in the release tag) so a mismatch is detected without fetching a
      multi-hundred-MB zip.

Restore refuses a mismatching artifact and falls back to a local build.

Open: the file name has no host or version in it. Either put them in the
release tag (§7) or extend the name later to
`otp-<otp_vsn>-<platform>-<arch>-<host>.zip`.

### 3. Relocatability (check before building anything else)

The tree will be unpacked under another project's `_build/…/arch-<arch>/`, so
absolute paths differ.

- [ ] After prepare, grep the tree for the build path
      (`grep -rl "$BUILD_PATH" otp/`). Expected hits: `config.status`, generated
      Makefiles under `make/<target>/` and `erts/<target>/`, `.d`/`*.depend`
      dependency files, and the `release/` start scripts (`ROOTDIR`).
- [ ] The final `build` step reruns `./otp_build configure`, which regenerates
      the configure output. Check whether the dependency files would make `make`
      rebuild everything, or fail on missing absolute prerequisites.
- [ ] Test: prepare in `/tmp/a`, move the tree to `/tmp/b`, run `otp.mk build`
      with the new `BUILD_PATH` and check (a) it succeeds, (b) the rebuild
      stays incremental (time it against a full build).
- [ ] If it is not relocatable, the fallback is a path-rewrite step on restore
      (`sed` over the listed files), or building under a fixed path in CI.

### 4. Archive format

- [ ] Use the `zip -ry` / `unzip` CLIs, **not** Erlang's `:zip`. `:zip` drops
      unix permissions (`otp_build`, `configure`, the bootstrap `erlexec` and
      other executables) and does not keep symlinks. Info-ZIP keeps permissions,
      symlinks (`-y`) and mtimes.
- [ ] mtimes matter: `$(STAMP_PREPARE)` depends on `otp/otp_build`. If the
      stamp ends up older than `otp_build`, make reruns the whole prepare
      (including `git clean -xdf`).
- [ ] If zip turns out too limiting, `tar.zst` is the fallback (same CLI
      approach).

### 5. Makefile changes (`priv/otp.mk`)

- [ ] `$(BUILD_PATH)/otp/otp_build` has an order-only prerequisite on
      `$(DEPS_PATH)/otp/otp_build`. Make still requires it to exist even when
      the target is up to date, so a restored tree would fail with
      "No rule to make target" unless `deps/otp` is fetched. Fetching it is
      exactly what the cache should avoid. Give it a no-op rule, or guard it
      with `$(wildcard …)`.
- [ ] Leave `prepare` as is otherwise: once the stamp and the tree are
      restored, `make prepare` is a no-op.

### 6. Mix side

New task `mix runtimes.otp` (or subcommands of `mix runtimes`):

- [ ] `mix runtimes.otp pack --archs <archs> [--output dir]`: requires a
      prepared tree (stamp present). Writes the manifest, zips §1 into
      `otp-<platform>-<arch>.zip`, and also writes a `.sha256` next to it.
- [ ] `mix runtimes.otp fetch --archs <archs> [--from url|path]`: downloads
      the zip (`:httpc` + `:public_key` for TLS, no new dependency), checks the
      sha256, unzips it into `build_path(arch)` and checks the manifest
      against the local key (§2).
- [ ] Base URL defaults to the GitHub release (§7) and can be overridden in
      project config (`:otp_artifact_url`) or with `RUNTIMES_OTP_URL`, for
      mirrors and offline use. Accept a local path too.
- [ ] Local download cache (`~/.cache/runtimes/` or `MIX_HOME`), so several
      projects or a `--clean` do not download again.

`mix runtimes.build`:

- [ ] Before `otp_mk(["prepare"], …)`, if `.stamp_otp_prepare` is missing,
      try `fetch`. On any failure (network, checksum, manifest mismatch), log
      the reason and run prepare locally.
- [ ] `--no-otp-cache` to force a local prepare.
- [ ] `--clean` today runs `git clean -xdf` in `otp/`, which needs `.git`.
      Define what clean means for a restored tree: probably
      `rm -rf otp .stamp_otp_*`, then fetch again.
- [ ] openssl: `compile.packages` has no manifest entry for openssl in a fresh
      project, so it will rebuild it and overwrite the restored `openssl/`.
      Same version, so this is harmless but slow. Options:
      (a) accept it for v1;
      (b) seed the `compile.packages` manifest entry on restore. The entry
          includes the full env, which has absolute paths, so it has to be
          computed locally and not shipped.
      Start with (a).

`mix runtimes.packages fetch`:

- [ ] Do not fetch `otp.mk` sources when a matching artifact is restored, or
      add a flag to skip them.

### 7. Publishing (CI)

- [ ] New workflow `.github/workflows/otp-artifacts.yml`, triggered manually
      (`workflow_dispatch`) and on changes to `priv/otp.mk` or
      `priv/packages/openssl.mk`.
- [ ] Matrix: `platform=android`, `arch=[arm, arm64, x86_64]`, on
      `ubuntu-latest` (linux-x86_64 host). Pin the NDK version with
      `nttld/setup-ndk` or similar; the NDK is part of the key.
- [ ] Steps: `mix runtimes.packages fetch` (openssl + otp only),
      `mix compile.packages --archs $arch openssl`,
      `make -f priv/otp.mk prepare` with the build env (or a
      `mix runtimes.build --prepare-only` flag), then
      `mix runtimes.otp pack`.
- [ ] Upload `otp-android-<arch>.zip` + `.sha256` as assets of a GitHub
      release tagged `otp-<OTP TAG>-<n>`, e.g. `otp-OTP-29.0.3-1`. The runtimes
      lib knows the tag it expects (a constant next to `TAG` in `otp.mk`, or
      derived from it), so the URL is deterministic.
- [ ] Check the asset size against the GitHub limit (2 GB per release asset).

### 8. Tests

- [ ] Unit: manifest generation and comparison (field mismatch, wrong
      `format`).
- [ ] Unit: pack/unpack round trip on a small fake tree keeps the exec bit,
      symlinks and mtimes.
- [ ] Unit: fallback to a local prepare when the fetch fails (stub the
      downloader).
- [ ] Manual / CI: in a fresh project, `MIX_TARGET=android mix runtimes.build
      --archs arm64 esqlite` with the artifact. It must not touch `deps/otp`,
      must not run `otp_build setup`, and the resulting `liberlang.a` must link
      in the app.

### 9. Docs

- [ ] README: cached OTP, how to disable it, how to point to a mirror, how to
      publish your own (`mix runtimes.otp pack`).

### Later

- [ ] Same approach for the arch-independent Elixir build
      (`arch-indep/elixir`): `elixir-<vsn>.zip`.
- [ ] Cache openssl too, or more generally any `packages/*.mk` output.
- [ ] darwin host artifacts (macOS runner).

## Multi-platform groundwork

Fixes and generic changes needed before a second platform (iOS, below) can
be added cleanly. None of them is iOS-specific; most also fix or simplify
Android.

### 1. Platform contract

- [x] `@behaviour Runtimes.Platform` with `archs/0`, `get_arch/1`,
      `build_env/2`, `nif_env/2`, and a `Runtimes.Platform.arch()` type.
      `Runtimes.Android` declares it.
- [ ] Add `merge_archives/3` (§2), `package/1` (§2, optional callback) and
      `install_program/0` (§5) to the behaviour as those items land.

### 2. Runtime assembly

- [ ] Nothing creates `liberlang.a`: `Runtimes.Common.artifact_path/1`
      points at `arch-<id>/liberlang.a`, but `otp.mk install` only copies
      loose `.a` files into `staging/otp/`. After `otp.mk install`, merge
      `staging/otp/*.a`, `staging/openssl/lib{crypto,ssl}.a`, NIF archives and
      package archives into `artifact_path(arch)`.
- [ ] The merge tool is per platform: callback
      `merge_archives(files, target, env)`. Android: the `ar -M` MRI script
      (`Runtimes.merge_archives/4` in desktop-runtimes; plain
      `ar rcs out.a in.a` nests archives instead of flattening them).
- [ ] Final OTP link: the `build` step needs the NIFs' dependency archives
      (libgit2, libssh2, libssl, libcrypto) in `LIBS`, not only the NIF
      archives and `EXTRA_RUNTIME` `-l` flags. Add every `staging/<pkg>/*.a`
      of the resolved package set.
- [ ] Optional platform-level step after the arch loop: callback
      `package(archs)`, returning the platform artifact path. Android could
      zip the per-ABI `liberlang.a` like desktop-runtimes'
      `android-runtime.zip`; iOS builds the xcframework.
- [ ] `mix runtimes artifact` without an arch: print the platform artifact.

### 3. Packages

- [ ] Makefile metadata cannot vary per platform: `Package.makefile_var/2`
      runs `make` without `PLATFORM`. Pass `PLATFORM=<name>` on its command
      line (`Package.create` needs the platform; `Packages.lookup/3` has it)
      so a makefile can say `EXTRA_RUNTIME_android = c++_static c++abi` and
      `EXTRA_RUNTIME = $(EXTRA_RUNTIME_$(PLATFORM))`. Migrate `egit.mk`.
      Document the pattern in the README.
- [ ] Add `OPENSSL_ARCH` (`arch.openssl_arch`) to `base_env/2`, so
      `openssl.mk` stops deriving its target from `ARCH` per platform.
      Android archs already carry the field.

### 4. OTP makefile

- [ ] `otp.mk` hardcodes `--xcomp-conf=xcomp/erl-xcomp-$(ARCH_XCOMP).conf`.
      Add an `XCOMP_CONF` variable defaulting to that, so a platform can
      ship its own conf in `priv/xcomp/`.
- [ ] `runtimes.build.ex` sets `RELEASE_BEAM=yes`; the OTP variable is
      `RELEASE_LIBBEAM`. Harmless today (`otp.mk install` picks `libbeam.a`
      from `bin/`, where it is always built), but fix the name.

### 5. Host handling

- [ ] `Runtimes.Android.nif_env/2` hardcodes
      `toolchains/llvm/prebuilt/linux-x86_64/sysroot` in `LDFLAGS`, so
      Android NIFs cannot be built on a macOS host. Use the same host
      directory as `bin_path/0`.
- [ ] `Runtimes.Common.host/0` returns `darwin-x86_64` on Apple Silicon too.
      That is right for the NDK prebuilt directory (it is universal) but not
      as a general host name, and the OTP cache key above relies on `HOST`.
      Move the NDK naming into `Runtimes.Android` and make `host/0` report
      the real arch.
- [ ] `install_program/0` assumes `llvm-strip` is in `PATH` on Linux (true
      with the NDK, not in general). Make it a platform callback.

### 6. Tests

- [ ] A platform-conditional makefile variable is read with the right
      `PLATFORM`.
- [ ] Archive merge with host `ar` on two tiny fake archives: the result
      lists the members, not nested archives.

## iOS platform

Depends on the multi-platform groundwork above, which it was extracted from.

### Goal

Add an `ios` platform next to `android`, producing a per-arch `liberlang.a`
and a `liberlang.xcframework` that can be dropped into an Xcode project.

Reference implementation: desktop-runtimes (`lib/runtimes/ios.ex`,
`lib/mix/tasks/package_ios_{runtime,nif}.ex`). It does the following:

- drives every tool through `xcrun -sdk <iphoneos|iphonesimulator> <tool>
  -arch <cpu>`;
- builds OTP with the stock `xcomp/erl-xcomp-*-ios*.conf` and
  `RELEASE_LIBBEAM=yes`;
- per arch, merges every target `.a` + `libcrypto.a` + NIF archives into
  `liberlang.a` with `libtool -static`;
- `lipo`s the simulator archs together, then runs
  `xcodebuild -create-xcframework`.

All of it needs a macOS host with Xcode (see §7 for Linux).

OTP 29 already ships the confs needed: `erl-xcomp-arm64-ios.conf`,
`erl-xcomp-arm64-iossimulator.conf`, `erl-xcomp-x86_64-iossimulator.conf`
(all with `--enable-static-nifs --enable-static-drivers --disable-jit`).

### 1. Platform module `Runtimes.Ios`

- [ ] `lib/runtimes/ios.ex`, registered as `ios: Runtimes.Ios` in
      `@platforms` (`lib/runtimes.ex`), implementing
      `@behaviour Runtimes.Platform`.
- [ ] Archs (armv7 dropped, current Xcode cannot target it):

      | id           | sdk             | cpu    | xcomp                 | name                         | openssl_arch                |
      |--------------|-----------------|--------|-----------------------|------------------------------|-----------------------------|
      | `arm64`      | iphoneos        | arm64  | `arm64-ios`           | `aarch64-apple-ios`          | `ios64-xcrun`               |
      | `sim-arm64`  | iphonesimulator | arm64  | `arm64-iossimulator`  | `aarch64-apple-iossimulator` | `iossimulator-arm64-xcrun`  |
      | `sim-x86_64` | iphonesimulator | x86_64 | `x86_64-iossimulator` | `x86_64-apple-iossimulator`  | `iossimulator-x86_64-xcrun` |

      `name` must be the triple OTP canonicalizes `erl_xcomp_host` to:
      `otp_nifs/1` and `otp.mk install` filter paths on it. Values come from
      desktop-runtimes; check against `otp/bin/` after the first build.
- [ ] `build_env/2`: raise unless `:os.type() == {:unix, :darwin}` (until
      §7). Set `CC`/`CXX`/`LD`/`AR`/`RANLIB`/`LIBTOOL` to
      `xcrun -sdk <sdk> <tool> [-arch <cpu>]`, `SDKROOT`,
      `IPHONEOS_DEPLOYMENT_TARGET` (clang honors it natively, which
      sidesteps the `-mios-version-min=7.0.0` hardcoded in the confs),
      `IOS_SDK`, `IOS_CPU`, `CFLAGS`/`CXXFLAGS` `-Os -fno-common`.
- [ ] Deployment target: one value, overridable from project config. See the
      egit note in §2 before picking it.
- [ ] `nif_env/2`: `CROSSCOMPILE=iOS`, `-isysroot $SDKROOT` in
      `CFLAGS`/`CXXFLAGS`, `LDFLAGS=-lc++`.
- [ ] `merge_archives/3`: `libtool -static`.
- [ ] Check first: whether env `CC`/`CFLAGS` win over the xcomp conf values
      or the other way round (Android currently sets both). Look at the
      compiler recorded in `config.log` for one arch.

### 2. Package makefiles

- [ ] `openssl.mk` `build-ios`: `./Configure $(OPENSSL_ARCH) no-shared
      --prefix=$(BUILD_PATH)/openssl`, then the same make steps as Android.
      The `*-xcrun` targets call xcrun themselves.
- [ ] `libssh2.mk`, `libgit2.mk` `build-ios`: cmake with
      `-DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=$(IOS_SDK)
      -DCMAKE_OSX_ARCHITECTURES=$(IOS_CPU)
      -DCMAKE_OSX_DEPLOYMENT_TARGET=$(IPHONEOS_DEPLOYMENT_TARGET)`, keeping
      the OpenSSL / static / `PKG_CONFIG_LIBDIR` settings.
- [ ] libgit2 on iOS: force `-DUSE_HTTPS=OpenSSL` (Apple targets default to
      SecureTransport), keep `-DREGEX_BACKEND=regcomp` (same PCRE symbol
      collision as Android), add `-DUSE_ICONV=OFF` (avoids an extra
      `-liconv`).
- [ ] `esqlite.mk`: should work as is (`CC`/`AR`/`RANLIB` only). Verify.
- [ ] `egit.mk`: no `EXTRA_RUNTIME` on iOS (libc++ comes from the SDK);
      relies on the platform-conditional variables from the groundwork.
- [ ] egit `HAVE_FORMAT=1`: Apple libc++ `std::format` needs a deployment
      target ≥ iOS 16.3. Either require that, or leave `HAVE_FORMAT` unset on
      iOS and let egit fall back to fmt. Decide.

### 3. xcframework

- [ ] `package/1`: `lipo -create` the simulator `liberlang.a`s, then write
      `_build/<target>_<env>/liberlang.xcframework` (device slice + fat
      simulator slice). Write its `Info.plist` and slice directories by hand
      rather than with `xcodebuild -create-xcframework`, so it also works on
      a Linux host (§7).

### 4. Tests

- [ ] Unit (no macOS needed): `Runtimes.find(:ios)` and archs (extend the
      doctest), non-darwin guard raises, xcframework `Info.plist` content.
- [ ] Manual: link the xcframework built with esqlite into a minimal Xcode
      app and boot the VM in the simulator.

### 5. CI

- [ ] `macos-latest` job, `workflow_dispatch` only (full OTP build is slow):
      `MIX_TARGET=ios mix runtimes.build --archs sim-arm64 esqlite`.
- [ ] Ties in with the OTP artifact cache above ("darwin host artifacts").

### 6. Docs

- [ ] README: `ios` in supported platforms, prerequisites (macOS, Xcode,
      `xcode-select`), how to consume the xcframework.

### 7. Linux host (optional, after macOS works)

Building on Ubuntu is possible with the SDK and tools that
[xtool](https://github.com/xtool-org/xtool) installs. Untested so far.

What xtool provides:

- `xtool sdk` extracts the iPhoneOS and iPhoneSimulator SDKs from a
  user-downloaded `Xcode.xip` (Apple ID needed) into
  `~/.swiftpm/swift-sdks/darwin.artifactbundle/Developer/Platforms/<Platform>.platform/Developer/SDKs/`.
- A toolset (`xtool-org/darwin-tools-linux-llvm`): `ld64.lld`,
  `llvm-libtool-darwin`, `dsymutil`. clang comes with the Swift toolchain.
- `llvm-ar`, `llvm-ranlib` and `llvm-lipo` come from a standard LLVM install.

What ties the macOS plan to macOS is `xcrun` (our env, the OTP xcomp
confs, OpenSSL's `*-xcrun` targets), plus `lipo`, `libtool` and
`xcodebuild`. OTP's own configure only uses `xcrun` for an optional PGO
probe (`erts/configure.ac:684`).

- [ ] `Runtimes.Ios.build_env/2` picks a toolchain by host instead of raising
      on non-darwin:

      | Step | macOS | Linux + xtool SDK |
      |---|---|---|
      | SDK root | `xcrun -sdk <sdk> --show-sdk-path` | `IOS_SDK_PATH`, or derived from the xtool bundle; raise if missing |
      | CC / CXX | `xcrun -sdk … cc -arch …` | `clang --target=<cpu>-apple-ios<min>[-simulator] -isysroot $SDK -fuse-ld=lld` |
      | AR / RANLIB | `xcrun ar` / `ranlib` | `llvm-ar` / `llvm-ranlib` |
      | LD | `xcrun ld` | `ld64.lld` |
      | archive merge | `libtool -static` | `llvm-libtool-darwin -static` |
      | fat simulator lib | `lipo` | `llvm-lipo` |
      | `install_program/0` | `/usr/bin/install -c` | `install -c -s --strip-program=llvm-strip` |

- [ ] OTP: ship our own xcomp confs without `xcrun` in `priv/xcomp/` for the
      Linux toolchain, selected through `XCOMP_CONF` (groundwork §4).
- [ ] `openssl.mk`: `ios64-cross` target with `CROSS_TOP`/`CROSS_SDK`
      instead of the `*-xcrun` targets.
- [ ] `libgit2.mk`, `libssh2.mk`: also pass `CMAKE_C_COMPILER`, `CMAKE_AR`,
      `CMAKE_RANLIB` and `CMAKE_OSX_SYSROOT=<sdk path>` (a path, not an SDK
      name).
- [ ] xcframework: write `Info.plist` and the per-slice directories by hand
      instead of calling `xcodebuild -create-xcframework`. Host-neutral, so
      do this from the start in §3 and use one code path on both hosts.
- [ ] First Linux check: bare OTP build for `sim-arm64`. OTP links a `beam`
      executable even for iOS, which is the first real use of `ld64.lld`
      against the SDK's `.tbd` stubs and the most likely failure point.

Caveats:

- Apple's Xcode and SDK agreement restricts use to Apple-branded computers.
  Extracting the SDK onto Linux goes against it. Do not cache or redistribute
  the SDK, nor publish Linux-built iOS artifacts from CI.
- App signing and submission still need Xcode (or `xtool dev` for local
  installs), so a Mac stays in the release path.

### Order

1. Groundwork §2 (Android `liberlang.a`), §3, §4, §5: can land and be tested
   on Android alone.
2. §1 + openssl, bare OTP build for `sim-arm64`: validates the conf/env
   interplay and the `name` triples.
3. §3 with esqlite only; link in a minimal Xcode app.
4. §2 libssh2, libgit2, egit.
5. Remaining archs, §5, §6.
6. §7 Linux host.

### Open

- Deployment target (tied to egit / `std::format`).
- Keep `sim-x86_64` (Intel Macs) or not.
- Whether Linux host support is worth it given the Xcode licence terms (§7).
