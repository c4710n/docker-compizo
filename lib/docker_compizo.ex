defmodule DockerCompizo do
  @moduledoc """
  Deploys a new version of Docker Compose service without downtime.
  """

  require Logger
  alias __MODULE__.BadEnv
  alias __MODULE__.BadRun
  alias __MODULE__.Default
  alias __MODULE__.Docker
  alias __MODULE__.Context
  alias __MODULE__.ComposeSpec
  alias __MODULE__.Compose
  alias __MODULE__.Image
  alias __MODULE__.Container

  def run(service, opts \\ []) do
    check_docker!()

    opts = Keyword.merge(Default.options(), opts)
    compose_file = Keyword.fetch!(opts, :compose_file)
    scale_opts = Keyword.take(opts, [:healthcheck_timeout, :no_healthcheck_timeout])

    context = %Context{
      docker_bin: System.find_executable("docker"),
      compose_file: compose_file
    }

    check_context!(context)
    check_service!(context, service)

    up_required_services!(context, service)

    if Compose.get_running_containers(context, service) == [] do
      up_service(context, service)
    else
      scale_bluegreen!(context, service, scale_opts)
    end
  end

  defp check_docker!() do
    if !Docker.is_installed?() do
      raise BadEnv, "docker - not installed"
    end

    if !Docker.is_compose_supported?() do
      raise BadEnv, "docker - missing support for compose"
    end
  end

  defp check_context!(context) do
    %{compose_file: compose_file} = context
    path = Path.relative_to_cwd(compose_file)

    case File.read(compose_file) do
      {:ok, _} ->
        case Compose.validate(context) do
          :ok -> :ok
          :error -> raise BadEnv, "bad Compose configuration file - #{path}"
        end

      {:error, posix} when posix in [:enoent, :enotdir] ->
        raise BadEnv, "missing file - #{path}"

      {:error, :eisdir} ->
        raise BadEnv, "bad file - #{path}"

      _ ->
        raise BadEnv, "failed to read file - #{path}"
    end
  end

  defp check_service!(context, service) do
    context
    |> ComposeSpec.from_context!()
    |> ComposeSpec.get_service(service)
    |> case do
      nil -> raise BadEnv, "unknown service - #{service}"
      _ -> :ok
    end
  end

  defp up_required_services!(context, service) do
    all_services =
      context
      |> ComposeSpec.from_context!()
      |> ComposeSpec.get_all_services()

    running_services = Compose.get_running_services(context)

    required_services =
      all_services
      |> substract(running_services)
      |> substract([service])

    for service <- required_services do
      up_service(context, service)
    end
  end

  defp scale_bluegreen!(context, service, opts) do
    healthcheck_timeout = Keyword.fetch!(opts, :healthcheck_timeout)
    no_healthcheck_timeout = Keyword.fetch!(opts, :no_healthcheck_timeout)

    old_containers = Compose.get_running_containers(context, service)

    current_scale = Enum.count(old_containers)

    new_scale =
      context
      |> ComposeSpec.from_context!()
      |> ComposeSpec.get_service_scale(service)

    scale_service(context, service, current_scale, new_scale)

    new_containers = Compose.get_running_containers(context, service) -- old_containers

    if support_healthcheck?(context, service) do
      report("Waiting for new containers to be healthy (timeout: #{healthcheck_timeout} seconds)")

      if health?(context, new_containers, healthcheck_timeout) do
        report("Cleaning old containers")
        Container.destroy(context, old_containers)

        ok()
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

      ok()
    end
  end

  defp up_service(context, service) do
    report("Service '#{service}' is not running. Starting the service")
    Compose.up_service(context, service)
  end

  defp scale_service(context, service, current_scale, new_scale) do
    scale = current_scale + new_scale
    report("Scaling '#{service}' service from #{current_scale} to #{scale} containers")
    Compose.scale_service(context, service, scale)
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

  defp substract(a, b) when is_list(a) and is_list(b) do
    :ordsets.from_list(a)
    |> :ordsets.subtract(:ordsets.from_list(b))
    |> :ordsets.to_list()
  end

  defp report(msg) do
    IO.puts("> #{msg}")
  end

  # This function may seem unnecessary, but it helps me mark the point
  # where the program should terminate normally.
  defp ok() do
    :ok
  end

  defp abort!() do
    raise BadRun
  end
end

defmodule DockerCompizo.BadEnv do
  defexception [:message]
end

defmodule DockerCompizo.BadRun do
  defexception [:message]
end
