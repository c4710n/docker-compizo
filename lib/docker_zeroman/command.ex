defmodule DockerZeroman.Command do
  require Logger

  def run(type, cmd, args) when type in [:batch, :stream] and is_list(args) do
    case type do
      :batch -> batch_run(cmd, args)
      :stream -> stream_run(cmd, args)
    end
  end

  defp batch_run(cmd, args) do
    cli = "#{cmd} #{Enum.join(args, " ")}"

    System.cmd(cmd, args)
    |> case do
      {output, 0} ->
        {:ok, output}

      {_, exit_status} ->
        Logger.debug("failed to run `#{cli}`, #{exit_status}")
        :error
    end
  end

  defp stream_run(cmd, args) do
    cli = "#{cmd} #{Enum.join(args, " ")}"

    port =
      Port.open({:spawn_executable, cmd}, [
        {:args, args},
        :stream,
        :binary,
        :hide,
        :exit_status,
        :use_stdio,
        :stderr_to_stdout
      ])

    handle_stream(port, cli)
  end

  defp handle_stream(port, cli) do
    receive do
      {^port, {:data, data}} ->
        IO.write(data)
        handle_stream(port, cli)

      {^port, {:exit_status, 0}} ->
        :ok

      {^port, {:exit_status, exit_status}} when exit_status == 0 ->
        Logger.debug("failed to run `#{cli}`, #{exit_status}")
        :error
    end
  end
end
