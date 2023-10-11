defmodule DockerCompizo.CLI do
  def main(argv) do
    optimus =
      Optimus.new!(
        name: "docker-compizo",
        description: "Deploy a new version of Docker Compose service without downtime.",
        version: "0.1.0",
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
            default: Path.expand("compose.yaml", File.cwd!())
          ],
          healthcheck_timeout: [
            value_name: "SECONDS",
            short: "-t",
            long: "--healthcheck-timeout",
            help:
              "Time in seconds to wait for new container to become healthy, if the container has healthcheck defined in 'Dockerfile' or 'compose.yml'.",
            parser: :integer,
            required: false,
            default: 60
          ],
          no_healthcheck_timeout: [
            value_name: "SECONDS",
            short: "-w",
            long: "--no-healthcheck-timeout",
            help:
              "Time in seconds to wait for new container to be ready, if the container doesn't have healthcheck defined.",
            parser: :integer,
            required: false,
            default: 10
          ]
        ]
      )

    %{
      args: %{service: service},
      options: %{
        compose_file: compose_file,
        healthcheck_timeout: healthcheck_timeout,
        no_healthcheck_timeout: no_healthcheck_timeout
      }
    } = Optimus.parse!(optimus, argv)

    DockerCompizo.run(compose_file, service,
      healthcheck_timeout: healthcheck_timeout,
      no_healthcheck_timeout: no_healthcheck_timeout
    )
  end
end
