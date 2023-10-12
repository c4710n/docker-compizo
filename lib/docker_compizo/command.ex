defmodule DockerCompizo.Command do
  require Logger

  def run(type, cmd, args, opts \\ []) when type in [:batch, :stream] and is_list(args) do
    case type do
      :batch -> batch_run(cmd, args, opts)
      :stream -> stream_run(cmd, args, opts)
    end
  end

  defp batch_run(cmd, args, opts) do
    cli = "#{cmd} #{Enum.join(args, " ")}"
    silent = Keyword.get(opts, :silent)

    System.cmd(cmd, args, stderr_to_stdout: true)
    |> case do
      {output, 0} ->
        {:ok, output}

      {_, exit_status} ->
        unless silent, do: Logger.debug("failed to run `#{cli}`, #{exit_status}")
        :error
    end
  end

  defp stream_run(cmd, args, opts) do
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

    handle_stream(port, cli, opts)
  end

  defp handle_stream(port, cli, opts) do
    silent = Keyword.get(opts, :silent)

    receive do
      {^port, {:data, data}} ->
        IO.write(data)
        handle_stream(port, cli, opts)

      {^port, {:exit_status, 0}} ->
        :ok

      {^port, {:exit_status, exit_status}} when exit_status == 0 ->
        unless silent, do: Logger.debug("failed to run `#{cli}`, #{exit_status}")
        :error
    end
  end
end
