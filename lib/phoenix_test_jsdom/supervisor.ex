defmodule PhoenixTestJsdom.Supervisor do
  @moduledoc false
  use Supervisor

  def child_spec(_opts), do: %{id: __MODULE__, start: {__MODULE__, :start_link, []}, type: :supervisor}

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @impl true
  def init(:ok) do
    children = [PhoenixTestJsdom.NodeWorker, PhoenixTestJsdom.ViewRegistry]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
