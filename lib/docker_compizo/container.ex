defmodule DockerCompizo.Container do
  alias DockerCompizo.Context
  alias DockerCompizo.Command

  def get_compose_config_hash(%Context{} = context, container) do
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

  def check_health_util_timeout(%Context{} = context, containers, timeout) do
    tasks =
      Enum.map(containers, fn container ->
        Task.async(fn -> check_health_periodically(context, container) end)
      end)

    tasks_with_results = Task.yield_many(tasks, :timer.seconds(timeout))

    Enum.map(tasks_with_results, fn {task, result} ->
      # shutdown the tasks that keep running past the timeout
      result || Task.shutdown(task, :brutal_kill)
    end)

    expected_checks = Enum.count(containers)

    passed_checks =
      Enum.count(tasks_with_results, fn {_task, result} ->
        match?({:ok, true}, result)
      end)

    expected_checks == passed_checks
  end

  defp check_health_periodically(context, container) do
    case get_health_state(context, container) do
      :healthy ->
        true

      _ ->
        Process.sleep(:timer.seconds(1))
        check_health_periodically(context, container)
    end
  end

  defp get_health_state(%Context{} = context, container) do
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
