defmodule PhoenixTestJsdom.CounterLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket, count: 0, name: "")}
  end

  def render(assigns) do
    ~H"""
    <div>
      <h1>Counter: {@count}</h1>
      <button phx-click="inc">Increment</button>
      <button phx-click="dec">Decrement</button>

      <form phx-submit="set_name">
        <label for="name-input">Name</label>
        <input id="name-input" name="name" type="text" value={@name} />
        <button type="submit">Set Name</button>
      </form>

      <p :if={@name != ""}>Hello, {@name}!</p>
    </div>
    """
  end

  def handle_event("inc", _params, socket) do
    {:noreply, update(socket, :count, &(&1 + 1))}
  end

  def handle_event("dec", _params, socket) do
    {:noreply, update(socket, :count, &(&1 - 1))}
  end

  def handle_event("set_name", %{"name" => name}, socket) do
    {:noreply, assign(socket, name: name)}
  end
end
