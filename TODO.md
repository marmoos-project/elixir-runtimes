# TODO: cache prepared OTP as a downloadable artifact

## Goal

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

## 1. Artifact content

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

## 2. Compatibility key and manifest

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

## 3. Relocatability (check before building anything else)

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

## 4. Archive format

- [ ] Use the `zip -ry` / `unzip` CLIs, **not** Erlang's `:zip`. `:zip` drops
      unix permissions (`otp_build`, `configure`, the bootstrap `erlexec` and
      other executables) and does not keep symlinks. Info-ZIP keeps permissions,
      symlinks (`-y`) and mtimes.
- [ ] mtimes matter: `$(STAMP_PREPARE)` depends on `otp/otp_build`. If the
      stamp ends up older than `otp_build`, make reruns the whole prepare
      (including `git clean -xdf`).
- [ ] If zip turns out too limiting, `tar.zst` is the fallback (same CLI
      approach).

## 5. Makefile changes (`priv/otp.mk`)

- [ ] `$(BUILD_PATH)/otp/otp_build` has an order-only prerequisite on
      `$(DEPS_PATH)/otp/otp_build`. Make still requires it to exist even when
      the target is up to date, so a restored tree would fail with
      "No rule to make target" unless `deps/otp` is fetched. Fetching it is
      exactly what the cache should avoid. Give it a no-op rule, or guard it
      with `$(wildcard …)`.
- [ ] Leave `prepare` as is otherwise: once the stamp and the tree are
      restored, `make prepare` is a no-op.

## 6. Mix side

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

## 7. Publishing (CI)

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

## 8. Tests

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

## 9. Docs

- [ ] README: cached OTP, how to disable it, how to point to a mirror, how to
      publish your own (`mix runtimes.otp pack`).

## Later

- [ ] Same approach for the arch-independent Elixir build
      (`arch-indep/elixir`): `elixir-<vsn>.zip`.
- [ ] Cache openssl too, or more generally any `packages/*.mk` output.
- [ ] darwin host artifacts (macOS runner).
