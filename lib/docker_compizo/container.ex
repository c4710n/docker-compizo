defmodule DockerCompizo.Container do
  alias DockerCompizo.Context
  alias DockerCompizo.Command

  def get_container_compose_config_hash(%Context{} = context, container) do
    {:ok, line} =
      Command.run(:batch, bin(context), [
        "inspect",
        "--format",
        "{{index .Config.Labels \"com.docker.compose.config-hash\"}}",
        container
      ])

    case String.trim(line) do
      "" -> nil
      hash -> hash
    end
  end

  def get_health_status(%Context{} = context, container) do
    {:ok, json_string} = Command.run(:batch, bin(context), ["inspect", "--format", "{{json .State.Health}}", container])

    case Jason.decode!(json_string) do
      %{"Status" => "starting"} -> :starting
      %{"Status" => "healthy"} -> :healthy
      %{"Status" => "unhealthy"} -> :unhealthy
      _ -> :unknown
    end
  end

  def destroy(%Context{} = context, containers) when is_list(containers) do
    for container <- containers do
      destroy(context, container)
    end

    :ok
  end

  def destroy(%Context{} = context, container) do
    {:ok, _} = Command.run(:batch, bin(context), ["stop", container])
    {:ok, _} = Command.run(:batch, bin(context), ["rm", container])

    :ok
  end

  defp bin(context), do: context.docker_bin
end
