defmodule PhoenixTestJsdom.ViewRegistry do
  @moduledoc false

  use GenServer

  alias PhoenixTestJsdom.Jsdom

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, Keyword.put_new(opts, :name, __MODULE__))
  end

  def put(key, jsdom_id) do
    GenServer.call(__MODULE__, {:put, key, jsdom_id})
  end

  def fetch(view) do
    GenServer.call(__MODULE__, {:fetch, registry_key(view)})
  end

  def fetch!(view) do
    case fetch(view) do
      {:ok, id} ->
        id

      :error ->
        raise "JSDom instance not found for view #{inspect(registry_key(view))}. Did you call PhoenixTestJsdom.mount/1?"
    end
  end

  def delete(key) do
    GenServer.cast(__MODULE__, {:delete, key})
  end

  defp registry_key(%Phoenix.LiveViewTest.View{pid: pid, id: id}), do: {pid, id}

  @impl true
  def init(:ok) do
    {:ok, %{entries: %{}, monitors: %{}}}
  end

  @impl true
  def handle_call({:put, key, jsdom_id}, _from, state) do
    {pid, _} = key
    ref = if is_pid(pid) and pid != self(), do: Process.monitor(pid), else: nil
    state = put_in(state.entries[key], jsdom_id)
    state = if ref, do: put_in(state.monitors[ref], key), else: state
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:fetch, key}, _from, state) do
    {:reply, Map.fetch(state.entries, key), state}
  end

  @impl true
  def handle_cast({:delete, key}, state) do
    {jsdom_id, entries} = Map.pop(state.entries, key)
    if jsdom_id, do: Jsdom.destroy(jsdom_id)
    {:noreply, %{state | entries: entries}}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    case Map.pop(state.monitors, ref) do
      {nil, monitors} ->
        {:noreply, %{state | monitors: monitors}}

      {key, monitors} ->
        {jsdom_id, entries} = Map.pop(state.entries, key)
        if jsdom_id, do: Jsdom.destroy(jsdom_id)
        {:noreply, %{state | entries: entries, monitors: monitors}}
    end
  end
end
