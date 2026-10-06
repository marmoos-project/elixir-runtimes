defmodule Runtimes.PackagesTest do
  use ExUnit.Case, async: false

  import Runtimes.RepoHelpers

  alias Runtimes.Package
  alias Runtimes.Packages
  alias Runtimes.Packages.Repo

  setup :start_repo

  describe "resolve/1" do
    test "adds transitive deps, in dependency order" do
      names = [Repo.find("nifa")] |> Packages.resolve() |> Enum.map(& &1.name)

      assert names == ["liba", "libb", "nifa"]
    end

    test "includes shared deps once" do
      names =
        ["nifa", "nifb"]
        |> Enum.map(&Repo.find/1)
        |> Packages.resolve()
        |> Enum.map(& &1.name)

      assert Enum.sort(names) == ["liba", "libb", "nifa", "nifb"]
      assert hd(names) == "liba"
    end

    test "raises on an unknown dep" do
      pkg = %Package{name: "broken", deps: ["missing"]}

      assert_raise Mix.Error, ~r/broken depends on unknown package missing/, fn ->
        Packages.resolve([pkg])
      end
    end
  end
end
