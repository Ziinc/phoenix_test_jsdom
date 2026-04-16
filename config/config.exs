import Config

if config_env() == :test do
  config :phoenix_test_jsdom, PhoenixTestJsdom.TestEndpoint,
    adapter: Bandit.PhoenixAdapter,
    http: [port: 4002],
    server: true,
    secret_key_base: String.duplicate("a", 64),
    live_view: [signing_salt: "test_signing_salt"],
    pubsub_server: PhoenixTestJsdom.PubSub,
    render_errors: [formats: [html: PhoenixTestJsdom.ErrorHTML], layout: false]

  config :phoenix_test, otp_app: :phoenix_test_jsdom

  config :logger, level: :warning
end
