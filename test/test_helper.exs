{:ok, _} =
  Supervisor.start_link([{Phoenix.PubSub, name: PhoenixTestJsdom.PubSub}], strategy: :one_for_one)

{:ok, _} = PhoenixTestJsdom.TestEndpoint.start_link()
ExUnit.start()
