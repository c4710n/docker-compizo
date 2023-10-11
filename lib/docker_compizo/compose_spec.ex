defmodule DockerCompizo.ComposeSpec do
  @enforce_keys [:parsed]
  defstruct [:parsed]

  alias YamlElixir, as: YAML
  alias DockerCompizo.Context

  def from_context!(%Context{} = context) do
    %__MODULE__{
      parsed: YAML.read_from_file!(context.compose_file)
    }
  end

  def get(%__MODULE__{parsed: parsed}, keys) when is_list(keys) do
    get_in(parsed, keys)
  end

  def has_healthcheck?(%__MODULE__{} = compose_spec, service) do
    !!get(compose_spec, ["services", service, "healthcheck"])
  end

  def get_all_services(%__MODULE__{} = compose_spec) do
    compose_spec
    |> get(["services"])
    |> Map.keys()
  end
end
