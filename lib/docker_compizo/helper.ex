defmodule DockerCompizo.Helper do
  alias DockerCompizo.BadRun

  def report(msg) do
    IO.puts("> #{msg}")
    :ok
  end

  def ok!() do
    :ok
  end

  def abort!() do
    raise BadRun
  end
end
