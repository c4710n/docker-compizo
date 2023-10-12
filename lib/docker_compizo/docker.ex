defmodule DockerCompizo.Docker do
  alias DockerCompizo.Command

  def is_installed?() do
    !!System.find_executable("docker")
  end

  def is_compose_supported?() do
    bin = System.find_executable("docker")

    case Command.run(:batch, bin, ["compose", "version"], silent: true) do
      {:ok, _} -> true
      _ -> false
    end
  end
end
