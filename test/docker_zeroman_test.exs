defmodule DockerZeromanTest do
  use ExUnit.Case
  doctest DockerZeroman

  test "greets the world" do
    assert DockerZeroman.hello() == :world
  end
end
