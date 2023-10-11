defmodule DockerCompizo do
  @moduledoc """
  Documentation for `DockerCompizo`.
  """

  require Logger
  alias __MODULE__.Context
  alias __MODULE__.ComposeSpec
  alias __MODULE__.Compose
  alias __MODULE__.Image
  alias __MODULE__.Container

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

    if Compose.get_running_containers(context, service) == [] do
      up_service(context, service)
    else
      scale_bluegreen!(context, service, opts)
    end
  end

  defp up_required_services!(context, service) do
    all_services =
      context
      |> ComposeSpec.from_context!()
      |> ComposeSpec.get_all_services()

    running_services = Compose.get_running_services(context)
    required_services = all_services -- running_services -- [service]

    for service <- required_services do
      up_service(context, service)
    end
  end

  defp scale_bluegreen!(context, service, opts) do
    healthcheck_timeout = Keyword.fetch!(opts, :healthcheck_timeout)
    no_healthcheck_timeout = Keyword.fetch!(opts, :no_healthcheck_timeout)

    old_containers = Compose.get_running_containers(context, service)

    from_count = Enum.count(old_containers)
    to_count = from_count * 2
    scale_service(context, service, from_count, to_count)

    new_containers = Compose.get_running_containers(context, service) -- old_containers

    if support_healthcheck?(context, service) do
      report("Waiting for new containers to be healthy (timeout: #{healthcheck_timeout} seconds)")

      if health?(context, new_containers, healthcheck_timeout) do
        report("Cleaning old containers")
        Container.destroy(context, old_containers)

        ok!()
      else
        report("New containers are not healthy. Rolling back")
        Container.destroy(context, new_containers)

        abort!()
      end
    else
      report("Waiting for new containers to be ready (timeout: #{no_healthcheck_timeout} seconds)")
      Process.sleep(:timer.seconds(no_healthcheck_timeout))

      report("Cleaning old containers")
      Container.destroy(context, old_containers)

      ok!()
    end
  end

  defp up_service(context, service) do
    report("Service '#{service}' is not running. Starting the service")
    Compose.up_service(context, service)
  end

  defp scale_service(context, service, from_count, to_count) do
    report("Scaling '#{service}' service from #{from_count} to #{to_count} containers")
    Compose.scale_service(context, service, to_count)
  end

  defp support_healthcheck?(context, service) do
    compose_spec = ComposeSpec.from_context!(context)
    image = ComposeSpec.get(compose_spec, ["services", service, "image"])

    ComposeSpec.has_healthcheck?(compose_spec, service) ||
      Image.has_healthcheck?(context, image)
  end

  defp health?(context, containers, timeout) do
    tasks =
      Enum.map(containers, fn container ->
        Task.async(fn -> loop_check_health(context, container) end)
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

  defp loop_check_health(context, container) do
    case Container.get_health_status(context, container) do
      :healthy ->
        true

      _ ->
        Process.sleep(:timer.seconds(1))
        loop_check_health(context, container)
    end
  end

  defp report(msg) do
    IO.puts("> #{msg}")
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
