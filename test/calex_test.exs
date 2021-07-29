defmodule CalexTest do
  use ExUnit.Case
  doctest Calex

  test "greets the world" do
    assert Calex.hello() == :world
  end
end
