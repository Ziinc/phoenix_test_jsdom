import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :hello, Hello.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "hello_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :hello, HelloWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "8+N6/5d1QtX0CDMRebCC7ILXScfaFSuMeZ38hlf5El0ZPNxb7DS2IrCxu+MdBPnT",
  server: true

# In test we don't send emails
config :hello, Hello.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# JSDom setup: shim window globals required by Monaco editor and set the
# working directory so Node can resolve npm packages from assets/node_modules
config :phoenix_test_jsdom,
  setup_files: [Path.expand("../assets/js/jsdom_setup.js", __DIR__)],
  cwd: Path.expand("../assets", __DIR__)
