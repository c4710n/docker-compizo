defmodule DockerCompizoTest do
  use ExUnit.Case
  doctest DockerCompizo

  test "greets the world" do
    assert DockerCompizo.hello() == :world
  end
end
