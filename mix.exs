defmodule DockerCompizo.MixProject do
  use Mix.Project

  def project do
    [
      app: :docker_compizo,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4"},
      {:yaml_elixir, "~> 2.9"},
      {:optimus, "~> 0.5"}
    ]
  end

  defp escript do
    [
      main_module: DockerCompizo.CLI,
      name: "docker-compizo"
    ]
  end
end
