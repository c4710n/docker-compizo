defmodule DockerCompizo.Image do
  alias DockerCompizo.Context
  alias DockerCompizo.Command

  def has_healthcheck?(%Context{} = context, image) do
    {:ok, json_string} =
      Command.run(:batch, bin(context), ["image", "inspect", "--format", "{{json .ContainerConfig}}", image])

    config = Jason.decode!(json_string)
    Map.has_key?(config, "Healthcheck")
  end

  defp bin(context), do: context.docker_bin
end
