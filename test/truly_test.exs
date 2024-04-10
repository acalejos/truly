defmodule TrulyTest do
  use ExUnit.Case
  doctest Truly

  test "greets the world" do
    assert Truly.hello() == :world
  end
end
