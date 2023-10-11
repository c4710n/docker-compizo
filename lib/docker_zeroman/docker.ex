defmodule DockerZeroman.Docker do
  alias DockerZeroman.Context
  alias DockerZeroman.Command

  def compose(type, context, args) do
    %Context{
      docker_bin: docker_bin,
      compose_file: compose_file
    } = context

    all_args =
      List.flatten([
        "compose",
        ["--ansi", "never"],
        ["--progress", "plain"],
        ["--file", compose_file],
        args
      ])

    Command.run(type, docker_bin, all_args)
  end

  def inspect(type, context, args) do
    %Context{docker_bin: docker_bin} = context

    all_args =
      List.flatten([
        "inspect",
        args
      ])

    Command.run(type, docker_bin, all_args)
  end

  def stop(type, context, args) do
    %Context{docker_bin: docker_bin} = context

    all_args =
      List.flatten([
        "stop",
        args
      ])

    Command.run(type, docker_bin, all_args)
  end

  def rm(type, context, args) do
    %Context{docker_bin: docker_bin} = context

    all_args =
      List.flatten([
        "rm",
        args
      ])

    Command.run(type, docker_bin, all_args)
  end
end
