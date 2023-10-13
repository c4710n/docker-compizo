defmodule DockerCompizo.Image do
  alias DockerCompizo.Context
  alias DockerCompizo.Command

  def exist?(%Context{} = context, image) do
    case Command.run(:batch, bin(context), ["image", "inspect", image], silent: true) do
      {:ok, _} -> true
      _ -> false
    end
  end

  def pull(%Context{} = context, image) do
    {:ok, _} = Command.run(:batch, bin(context), ["image", "pull", "-q", image])
  end

  def has_healthcheck?(%Context{} = context, image) do
    if !exist?(context, image), do: pull(context, image)

    {:ok, json_string} =
      Command.run(:batch, bin(context), ["image", "inspect", "--format", "{{json .ContainerConfig}}", image])

    config = Jason.decode!(json_string)
    Map.has_key?(config, "Healthcheck")
  end

  defp bin(context), do: context.docker_bin
end
