defmodule DockerCompizo do
  @moduledoc """
  Documentation for `DockerCompizo`.
  """

  require Logger
  alias __MODULE__.Context
  alias __MODULE__.Docker

  def run(compose_file, service, opts = [healthcheck_timeout: _, no_healthcheck_timeout: _]) do
    docker_bin = System.find_executable("docker")

    unless docker_bin do
      error!("Command docker is missing. Please install docker first.")
    end

    context = %Context{
      docker_bin: docker_bin,
      compose_file: compose_file
    }

    up_required_services!(context, service)

    if containers_running!(context, service) == [] do
      up!(context, service)
    else
      scale_bluegreen!(context, service, opts)
    end
  end

  defp up_required_services!(context, service) do
    required_services =
      services_missing!(context)
      |> List.delete(service)

    for service <- required_services do
      up!(context, service)
    end
  end

  defp scale_bluegreen!(context, service, opts) do
    healthcheck_timeout = Keyword.fetch!(opts, :healthcheck_timeout)
    no_healthcheck_timeout = Keyword.fetch!(opts, :no_healthcheck_timeout)

    old_containers = containers_running!(context, service)

    from_count = Enum.count(old_containers)
    to_count = from_count * 2
    scale!(context, service, from_count, to_count)

    old_one_container = List.first(old_containers)
    new_containers = containers_running!(context, service) -- old_containers

    if is_healthcheck_supported?(context, old_one_container) do
      report("Waiting for new containers to be healthy (timeout: #{healthcheck_timeout} seconds)")

      if health?(context, new_containers, healthcheck_timeout) do
        report("Removing old containers")
        remove!(context, old_containers)

        ok!()
      else
        report("New containers are not healthy. Rolling back")
        remove!(context, new_containers)

        abort!()
      end
    else
      report("Waiting for new containers to be ready (timeout: #{no_healthcheck_timeout} seconds)")
      Process.sleep(:timer.seconds(no_healthcheck_timeout))

      report("Removing old containers")
      remove!(context, old_containers)

      ok!()
    end
  end

  defp services_all!(context) do
    Docker.compose(:batch, context, ["config", "--services"])
    |> case do
      {:ok, services} -> String.split(services, "\n", trim: true)
      _ -> error!("Failed to get all services")
    end
  end

  defp services_running!(context) do
    Docker.compose(:batch, context, ["ps", "--services"])
    |> case do
      {:ok, services} -> String.split(services, "\n", trim: true)
      _ -> error!("Failed to get running services")
    end
  end

  defp services_missing!(context) do
    services_all!(context) -- services_running!(context)
  end

  defp containers_running!(context, service) do
    Docker.compose(:batch, context, ["ps", "--quiet", service])
    |> case do
      {:ok, containers} -> String.split(containers, "\n", trim: true)
      _ -> error!("Failed to get running containers")
    end
  end

  defp up!(context, service) do
    report("Service '#{service}' is not running. Starting the service")
    Docker.compose(:stream, context, ["up", "--detach", "--no-recreate", service])
  end

  defp scale!(context, service, from_count, to_count) do
    report("Scaling '#{service}' service from #{from_count} to #{to_count} containers")
    Docker.compose(:stream, context, ["up", "--detach", "--no-recreate", "--scale", "#{service}=#{to_count}", service])
  end

  defp remove!(context, containers) when is_list(containers) do
    for container <- containers do
      remove!(context, container)
    end

    :ok
  end

  defp remove!(context, container) do
    Docker.stop(:batch, context, [container])
    Docker.rm(:batch, context, [container])
  end

  defp is_healthcheck_supported?(context, container) do
    with {:ok, raw_json} <- Docker.inspect(:batch, context, ["--format", "{{json .State.Health}}", container]) do
      String.contains?(raw_json, "\"Status\"")
    else
      _ -> false
    end
  end

  defp health?(context, containers, timeout) do
    tasks =
      Enum.map(containers, fn container ->
        Task.async(fn -> healthcheck_loop(context, container) end)
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

  defp healthcheck_loop(context, container, opts \\ []) do
    interval = Keyword.get(opts, :interval, 1)
    health? = healthcheck(context, container)

    if health? do
      health?
    else
      Process.sleep(:timer.seconds(interval))
      healthcheck_loop(context, container, opts)
    end
  end

  defp healthcheck(context, container) do
    with {:ok, raw_json} <- Docker.inspect(:batch, context, ["--format", "{{json .State.Health.Status}}", container]),
         {:ok, status} <- Jason.decode(raw_json) do
      status == "healthy"
    else
      _ -> false
    end
  end

  defp report(msg) do
    IO.puts("==> #{msg}")
  end

  defp ok!() do
    System.stop(0)
  end

  defp abort!() do
    System.stop(1)
  end

  defp error!(msg) do
    IO.write(:stderr, "#{msg}.\n")
    System.stop(1)
  end
end
