defmodule PhoenixTestJsdom.NodeWorker do
  @moduledoc """
  GenServer that manages a persistent Node.js process via an Erlang Port.

  Communicates with `priv/server.js` using JSON over stdin/stdout.
  Supports concurrent callers via request IDs — each call gets a unique ID
  and the response is routed back to the correct caller.
  """
  use GenServer

  @timeout 30_000

  def child_spec(_opts), do: %{id: __MODULE__, start: {__MODULE__, :start_link, []}}

  def start_link do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def call(func, args \\ []) do
    GenServer.call(__MODULE__, {:call, func, args}, @timeout)
  end

  # GenServer callbacks

  def init(:ok) do
    node = find_node!()
    server_js = Path.join(:code.priv_dir(:phoenix_test_jsdom), "dist/server.bundle.js")
    cwd = Application.get_env(:phoenix_test_jsdom, :cwd)
    setup_files = resolve_setup_files()

    port_opts =
      [
        {:args, [server_js]},
        {:line, 1_048_576},
        :binary,
        :exit_status
      ]
      |> then(fn o ->
        if cwd, do: [{:cd, String.to_charlist(Path.expand(cwd))} | o], else: o
      end)

    port = Port.open({:spawn_executable, node}, port_opts)

    if setup_files != [] do
      payload =
        Jason.encode!(%{
          id: "__init__",
          fn: "__init",
          args: [
            %{
              setupFiles: Enum.map(setup_files, &Path.expand/1),
              cwd: cwd && Path.expand(cwd)
            }
          ]
        })

      Port.command(port, payload <> "\n")

      receive do
        {^port, {:data, {:eol, line}}} ->
          case Jason.decode(line) do
            {:ok, %{"id" => "__init__", "error" => err}} ->
              raise "phoenix_test_jsdom: setup_files init failed: #{err}"

            _ ->
              :ok
          end
      after
        30_000 -> raise "phoenix_test_jsdom: timeout waiting for __init response"
      end
    end

    {:ok, %{port: port, counter: 0, pending: %{}}}
  end

  def handle_call(
        {:call, func, args},
        from,
        %{port: port, counter: counter, pending: pending} = state
      ) do
    id = Integer.to_string(counter)
    msg = Jason.encode!(%{id: id, fn: func, args: args})
    Port.command(port, msg <> "\n")
    {:noreply, %{state | counter: counter + 1, pending: Map.put(pending, id, from)}}
  end

  def handle_info({port, {:data, {:eol, line}}}, %{port: port, pending: pending} = state) do
    case Jason.decode(line) do
      {:ok, %{"id" => id, "result" => result}} ->
        case Map.pop(pending, id) do
          {nil, _} ->
            {:noreply, state}

          {from, pending} ->
            GenServer.reply(from, {:ok, result})
            {:noreply, %{state | pending: pending}}
        end

      {:ok, %{"id" => id, "error" => error}} ->
        case Map.pop(pending, id) do
          {nil, _} ->
            {:noreply, state}

          {from, pending} ->
            GenServer.reply(from, {:error, error})
            {:noreply, %{state | pending: pending}}
        end

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({port, {:data, {:noeol, _}}}, %{port: port} = state) do
    {:noreply, state}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state) do
    {:stop, {:node_exited, status}, state}
  end

  def terminate(_reason, %{port: port}) do
    Port.close(port)
  catch
    _, _ -> :ok
  end

  defp resolve_setup_files do
    raw = Application.get_env(:phoenix_test_jsdom, :setup_files) || []

    case raw do
      files when is_list(files) -> files
      file when is_binary(file) -> [file]
      _ -> raise ArgumentError, "phoenix_test_jsdom: :setup_files must be a list of paths or a single path string"
    end
  end

  defp find_node! do
    cond do
      node = Application.get_env(:phoenix_test_jsdom, :node_path) -> node
      node = System.find_executable("mise") -> find_node_via_mise(node)
      node = System.find_executable("node") -> node
      true -> raise "Could not find node executable"
    end
  end

  defp find_node_via_mise(mise) do
    case System.cmd(mise, ["which", "node"], stderr_to_stdout: true) do
      {path, 0} -> String.trim(path)
      _ -> System.find_executable("node") || raise "Could not find node executable"
    end
  end
end
