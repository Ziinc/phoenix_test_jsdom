defmodule PhoenixTestJsdom.Application do
  use Application

  def start(_type, _args) do
    children = [PhoenixTestJsdom.NodeWorker]
    Supervisor.start_link(children, strategy: :one_for_one, name: PhoenixTestJsdom.Supervisor)
  end
end
