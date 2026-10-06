defmodule Runtimes.RepoHelpers do
  @moduledoc """
  Test helpers for running `Runtimes.Packages.Repo` against test makefiles.

  The repo is a named Agent, so tests using these helpers can't run
  concurrently (`async: false`).

  Fixture makefiles live in `test/fixtures`:

  - `packages/liba.mk` - no deps
  - `packages/libb.mk` - `DEPS = liba`
  - `nifs/nifa.mk` - `DEPS = libb`, `PLATFORMS = android`, `EXTRA_RUNTIME = c++_static`
  - `nifs/nifb.mk` - `DEPS = liba`
  """

  import ExUnit.Callbacks, only: [on_exit: 1]

  alias Runtimes.Packages.Repo

  @fixtures_path Path.expand("../fixtures", __DIR__)

  @doc "Directories holding the fixture NIF makefiles."
  def nifs_path, do: [Path.join(@fixtures_path, "nifs")]

  @doc "Directories holding the fixture package makefiles."
  def packages_path, do: [Path.join(@fixtures_path, "packages")]

  @doc """
  Starts a fresh repo loaded from the given paths, defaulting to the fixtures.

  Any repo already running is stopped first, since `Repo.ensure_started/1`
  ignores its paths when the repo is already up. The repo is stopped again
  when the test exits.

  Usable directly as a setup callback: `setup :start_repo`.
  """
  def start_repo(opts \\ [])

  def start_repo(%{} = _context), do: start_repo([])

  def start_repo(opts) do
    stop_repo()

    :ok =
      Repo.ensure_started(
        nifs_path: Keyword.get(opts, :nifs_path, nifs_path()),
        packages_path: Keyword.get(opts, :packages_path, packages_path())
      )

    on_exit(&stop_repo/0)
    :ok
  end

  @doc """
  Stops the repo if it is running.

  In `on_exit` the repo may already be gone, or going: it is linked to the
  test process, which has exited by then.
  """
  def stop_repo do
    Repo.stop()
  catch
    :exit, reason when reason in [:noproc, :shutdown] -> :ok
    :exit, {reason, _} when reason in [:noproc, :shutdown] -> :ok
  end
end
