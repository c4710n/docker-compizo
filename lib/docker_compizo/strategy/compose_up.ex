defmodule DockerCompizo.Strategy.ComposeUp do
  alias DockerCompizo.Compose
  alias DockerCompizo.Helper

  def deploy(context, service) do
    Helper.report("Deploying '#{service}' service with ComposeUp strategy")
    Compose.up_service(context, service)
  end
end
