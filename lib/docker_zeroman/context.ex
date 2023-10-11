defmodule DockerZeroman.Context do
  @enforce_keys [:docker_bin, :compose_file]
  defstruct [:docker_bin, :compose_file]
end
