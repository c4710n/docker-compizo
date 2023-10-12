defmodule DockerCompizo.Default do
  @moduledoc """
  Shares the default values between the core code and command line interface.
  """

  def options() do
    [
      compose_file: Path.expand("compose.yaml", File.cwd!()),
      healthcheck_timeout: 60,
      no_healthcheck_timeout: 10
    ]
  end
end
