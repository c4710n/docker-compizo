defmodule DockerCompizo.Compose do
  alias DockerCompizo.Context
  alias DockerCompizo.Command

  def validate_config(%Context{} = context) do
    case batch(context, ["config", "--quiet"]) do
      {:ok, _} -> :ok
      _ -> :error
    end
  end

  def get_service_config_hash(%Context{} = context, service) do
    {:ok, line} = batch(context, ["config", "--hash", service])

    [_name, hash] =
      line
      |> String.trim()
      |> String.split(" ", parts: 2)

    hash
  end

  def list_running_services(%Context{} = context) do
    {:ok, raw_services} = batch(context, ["ps", "--services"])
    String.split(raw_services, "\n", trim: true)
  end

  def list_running_containers(%Context{} = context, service) do
    {:ok, raw_containers} = batch(context, ["ps", "--quiet", service])
    String.split(raw_containers, "\n", trim: true)
  end

  def up_service(%Context{} = context, service) do
    :ok = stream(context, ["up", "--detach", "--no-recreate", service])
  end

  def scale_service(%Context{} = context, service, scale) do
    :ok = stream(context, ["up", "--detach", "--no-recreate", "--scale", "#{service}=#{scale}", service])
  end

  defp batch(context, args) do
    Command.run(
      :batch,
      bin(context),
      List.flatten([
        "compose",
        compose_args(context),
        args
      ])
    )
  end

  defp stream(context, args) do
    Command.run(
      :stream,
      bin(context),
      List.flatten([
        "compose",
        compose_args(context),
        args
      ])
    )
  end

  defp bin(context), do: context.docker_bin

  defp compose_args(context) do
    [
      "--ansi",
      "never",
      "--file",
      context.compose_file
    ]
  end
end
