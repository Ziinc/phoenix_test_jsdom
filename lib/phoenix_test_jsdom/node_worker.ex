defmodule PhoenixTestJsdom.NodeWorker do
  @moduledoc """
  GenServer that manages a persistent Node.js process via an Erlang Port.

  Communicates with `priv/server.js` using JSON over stdin/stdout.
  Supports concurrent callers via request IDs — each call gets a unique ID
  and the response is routed back to the correct caller.
  """
  use GenServer

  @timeout 30_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def call(func, args \\ []) do
    GenServer.call(__MODULE__, {:call, func, args}, @timeout)
  end

  # GenServer callbacks

  def init(_opts) do
    node = find_node!()
    server_js = Path.join(:code.priv_dir(:phoenix_test_jsdom), "dist/server.bundle.js")

    port =
      Port.open({:spawn_executable, node}, [
        {:args, [server_js]},
        {:line, 1_048_576},
        :binary,
        :exit_status
      ])

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
