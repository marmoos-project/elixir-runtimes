defmodule RuntimesTest do
  use ExUnit.Case
  doctest Runtimes

  test "greets the world" do
    assert Runtimes.hello() == :world
  end
end
