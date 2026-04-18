defmodule PhoenixTestJsdom.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    children = [{PhoenixTestJsdom.NodeWorker, opts}, PhoenixTestJsdom.ViewRegistry]
    Supervisor.init(children, strategy: :one_for_one)
  end
end
