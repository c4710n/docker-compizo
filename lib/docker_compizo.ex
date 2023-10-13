defmodule DockerCompizo do
  @moduledoc """
  Deploys a new version of Docker Compose service without downtime.
  """

  alias __MODULE__.BadEnv
  alias __MODULE__.Default
  alias __MODULE__.Docker
  alias __MODULE__.Context
  alias __MODULE__.ComposeSpec
  alias __MODULE__.Compose
  alias __MODULE__.Image
  alias __MODULE__.Container
  alias __MODULE__.Helper

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

    deploy_required_services!(context, service)
    deploy_current_service!(context, service, scale_opts)
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
        case Compose.validate_config(context) do
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

  defp deploy_required_services!(context, service) do
    all_services =
      context
      |> ComposeSpec.from_context!()
      |> ComposeSpec.list_services()

    running_services = Compose.list_running_services(context)

    required_services =
      all_services
      |> substract(running_services)
      |> substract([service])

    for required_service <- required_services do
      DockerCompizo.Strategy.ComposeUp.deploy(context, required_service)
    end

    :ok
  end

  defp deploy_current_service!(context, service, opts) do
    deploy_opts = [
      is_healthcheck_supported?: is_healthcheck_supported?(context, service),
      healthcheck_timeout: Keyword.fetch!(opts, :healthcheck_timeout),
      no_healthcheck_timeout: Keyword.fetch!(opts, :no_healthcheck_timeout)
    ]

    running_services = Compose.list_running_services(context)
    is_service_running? = service in running_services

    if !is_service_running? do
      DockerCompizo.Strategy.ComposeUp.deploy(context, service)
    else
      running_containers = Compose.list_running_containers(context, service)

      running_containers_config_hash =
        Enum.map(running_containers, fn container ->
          Container.get_compose_config_hash(context, container)
        end)

      service_config_hash = Compose.get_service_config_hash(context, service)

      is_service_config_hash_changed? = service_config_hash not in running_containers_config_hash

      old_scale = Enum.count(running_containers)

      new_scale =
        context
        |> ComposeSpec.from_context!()
        |> ComposeSpec.get_service_scale(service)

      is_scale_changed? = old_scale != new_scale

      if is_service_config_hash_changed? || is_scale_changed? do
        DockerCompizo.Strategy.BlueGreen.deploy(context, service, deploy_opts)
      else
        Helper.report("Compose config or scale of service isn't changed. Skip current deployment.")
      end
    end
  end

  defp is_healthcheck_supported?(context, service) do
    compose_spec = ComposeSpec.from_context!(context)
    image = ComposeSpec.get_service_image(compose_spec, service)

    ComposeSpec.has_service_healthcheck?(compose_spec, service) ||
      Image.has_healthcheck?(context, image)
  end

  defp substract(a, b) when is_list(a) and is_list(b) do
    :ordsets.from_list(a)
    |> :ordsets.subtract(:ordsets.from_list(b))
    |> :ordsets.to_list()
  end
end
