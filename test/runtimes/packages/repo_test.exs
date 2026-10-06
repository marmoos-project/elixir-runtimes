defmodule Runtimes.Packages.RepoTest do
  use ExUnit.Case, async: false

  import Runtimes.RepoHelpers

  alias Runtimes.Package
  alias Runtimes.Packages.Repo

  describe "with fixture makefiles" do
    setup :start_repo

    test "loads NIFs and packages with their type" do
      types = Map.new(Repo.all(), fn {name, pkg} -> {name, pkg.type} end)

      assert types == %{
               "nifa" => :nif,
               "nifb" => :nif,
               "liba" => :package,
               "libb" => :package
             }
    end

    test "find/1 returns the package by name, or nil" do
      assert %Package{name: "nifa", deps: ["libb"], platforms: ["android"]} = Repo.find("nifa")
      assert Repo.find("missing") == nil
    end

    test "add/1 adds or replaces a package" do
      Repo.add(%Package{name: "extra", type: :package})
      Repo.add(%Package{name: "liba", type: :package, tag: "v9"})

      assert %Package{name: "extra"} = Repo.find("extra")
      assert %Package{tag: "v9"} = Repo.find("liba")
    end

    test "ensure_started/1 on a running repo keeps its contents" do
      Repo.add(%Package{name: "extra", type: :package})

      assert :ok = Repo.ensure_started()
      assert %Package{name: "extra"} = Repo.find("extra")
    end
  end

  describe "start_repo/1" do
    test "loads only the given paths" do
      start_repo(nifs_path: nifs_path(), packages_path: [])

      assert Repo.all() |> Map.keys() |> Enum.sort() == ["nifa", "nifb"]
    end

    test "replaces a repo that is already running" do
      start_repo(nifs_path: [], packages_path: [])
      assert Repo.all() == %{}

      start_repo()
      assert map_size(Repo.all()) == 4
    end
  end
end
