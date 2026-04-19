defmodule PhoenixTestJsdom.NodeWorkerTest do
  use ExUnit.Case, async: false

  alias PhoenixTestJsdom.NodeWorker

  test "graceful stop kills the Node OS process" do
    pid = start_worker()
    node_pid = node_os_pid(pid)

    GenServer.stop(pid, :normal, 5_000)

    assert eventually_dead(node_pid)
  end

  test "brutal kill kills the Node OS process" do
    pid = start_worker()
    node_pid = node_os_pid(pid)
    ref = Process.monitor(pid)
    Process.unlink(pid)

    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}, 3_000

    assert eventually_dead(node_pid)
  end

  test "supervisor shutdown kills the Node OS process" do
    child_spec = %{id: :iso_worker, start: {GenServer, :start_link, [NodeWorker, :ok, []]}}
    {:ok, sup} = Supervisor.start_link([child_spec], strategy: :one_for_one)
    [{:iso_worker, worker_pid, :worker, _}] = Supervisor.which_children(sup)
    node_pid = node_os_pid(worker_pid)

    Supervisor.stop(sup, :normal)

    assert eventually_dead(node_pid)
  end

  test "Node process exit stops the GenServer with :node_exited reason" do
    pid = start_worker()
    ref = Process.monitor(pid)
    Process.unlink(pid)

    System.cmd("kill", ["-KILL", Integer.to_string(node_os_pid(pid))], stderr_to_stdout: true)

    assert_receive {:DOWN, ^ref, :process, ^pid, {:node_exited, _}}, 3_000
  end

  defp start_worker do
    # Bypasses the named global singleton so tests can terminate workers freely.
    {:ok, pid} = GenServer.start_link(NodeWorker, :ok, [])
    pid
  end

  defp node_os_pid(pid) do
    %{port: port} = :sys.get_state(pid)
    {:os_pid, os_pid} = Port.info(port, :os_pid)
    os_pid
  end

  defp eventually_dead(os_pid, timeout_ms \\ 2_000) do
    deadline = System.monotonic_time(:millisecond) + timeout_ms

    Enum.reduce_while(Stream.repeatedly(fn -> os_pid end), nil, fn os_pid, _ ->
      alive = match?({_, 0}, System.cmd("kill", ["-0", Integer.to_string(os_pid)], stderr_to_stdout: true))

      cond do
        not alive -> {:halt, true}
        System.monotonic_time(:millisecond) >= deadline -> {:halt, false}
        true -> Process.sleep(50); {:cont, nil}
      end
    end)
  end
end
