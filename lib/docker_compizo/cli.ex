defmodule DockerCompizo.CLI do
  @moduledoc """
  Provides CLI for `DockerCompizo`.

  ## TODO

  * optimus - the command line parser, just works. But it is not aesthetically
    pleasing or refined. I will replace it at the appropriate time.

  """

  alias DockerCompizo.Default
  alias DockerCompizo.BadEnv
  alias DockerCompizo.BadRun

  def main(argv) do
    defaultOptions = Default.options()

    optimus =
      Optimus.new!(
        name: "docker-compizo",
        description: "Deploy a new version of Docker Compose service without downtime.",
        allow_unknown_args: false,
        args: [
          service: [
            value_name: "SERVICE",
            help: "Docker Compose service name",
            required: true,
            parser: :string
          ]
        ],
        options: [
          compose_file: [
            value_name: "FILE",
            short: "-f",
            long: "--file",
            help: "Compose configuration files. Can be specified multiple times, as in `docker compose`.",
            parser: fn v ->
              {:ok, Path.expand(v, File.cwd!())}
            end,
            required: false,
            default: Keyword.fetch!(defaultOptions, :compose_file)
          ],
          healthcheck_timeout: [
            value_name: "SECONDS",
            short: "-t",
            long: "--healthcheck-timeout",
            help:
              "Time in seconds to wait for new container to become healthy, if the container has healthcheck defined in 'Dockerfile' or 'compose.yml'.",
            parser: :integer,
            required: false,
            default: Keyword.fetch!(defaultOptions, :healthcheck_timeout)
          ],
          no_healthcheck_timeout: [
            value_name: "SECONDS",
            short: "-w",
            long: "--no-healthcheck-timeout",
            help:
              "Time in seconds to wait for new container to be ready, if the container doesn't have healthcheck defined.",
            parser: :integer,
            required: false,
            default: Keyword.fetch!(defaultOptions, :no_healthcheck_timeout)
          ]
        ]
      )

    %{
      args: %{service: service},
      options:
        %{
          compose_file: _,
          healthcheck_timeout: _,
          no_healthcheck_timeout: _
        } = opts
    } = Optimus.parse!(optimus, argv)

    try do
      DockerCompizo.run(service, Map.to_list(opts))
      System.stop(0)
    rescue
      error in [BadEnv, BadRun] ->
        abort!(error)
    end
  end

  defp abort!(error) do
    IO.write(:stderr, "#{error.message}\n")
    System.stop(1)
  end
end
