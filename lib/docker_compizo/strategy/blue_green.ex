defmodule DockerCompizo.Strategy.BlueGreen do
  alias DockerCompizo.Compose
  alias DockerCompizo.ComposeSpec
  alias DockerCompizo.Container
  alias DockerCompizo.Helper

  def deploy(context, service,
        is_healthcheck_supported?: is_healthcheck_supported?,
        healthcheck_timeout: healthcheck_timeout,
        no_healthcheck_timeout: no_healthcheck_timeout
      ) do
    Helper.report("Deploying '#{service}' service with Blue/Green strategy")

    old_containers = Compose.list_running_containers(context, service)
    old_scale = Enum.count(old_containers)

    new_scale =
      context
      |> ComposeSpec.from_context!()
      |> ComposeSpec.get_service_scale(service)

    Helper.report("Scaling containers from #{old_scale} to #{new_scale}")
    scale_total = old_scale + new_scale
    Compose.scale_service(context, service, scale_total)

    all_containers = Compose.list_running_containers(context, service)
    new_containers = all_containers -- old_containers

    if is_healthcheck_supported? do
      Helper.report("Waiting for new containers to be healthy (timeout: #{healthcheck_timeout} seconds)")

      if Container.check_health_util_timeout(context, new_containers, healthcheck_timeout) do
        Helper.report("Cleaning old containers")
        Container.destroy(context, old_containers)

        Helper.ok!()
      else
        Helper.report("New containers are not healthy. Rolling back")
        Container.destroy(context, new_containers)

        Helper.abort!()
      end
    else
      Helper.report("Waiting for new containers to be ready (timeout: #{no_healthcheck_timeout} seconds)")
      Process.sleep(:timer.seconds(no_healthcheck_timeout))

      Helper.report("Cleaning old containers")
      Container.destroy(context, old_containers)

      Helper.ok!()
    end
  end
end
