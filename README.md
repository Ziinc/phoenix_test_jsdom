# PhoenixTestJsdom

A [PhoenixTest](https://hexdocs.pm/phoenix_test) driver that uses [JSDom](https://github.com/jsdom/jsdom) for lightweight headless browser testing of Phoenix applications.

## Features

- Full `PhoenixTest.Driver` protocol implementation
- Real DOM fidelity via JSDom (no browser required)
- Async test support with isolated JSDom instances
- Seamless LiveView support (delegates to PhoenixTest's Live driver)
- Static page support with form interactions (fill_in, select, check, submit)

## Quickstart

1. Add the dependency to `mix.exs`:

```elixir
def deps do
  [
    {:phoenix_test_jsdom, "~> 0.1.0", only: :test}
  ]
end
```

2. Fetch dependencies:

```bash
mix deps.get
```

> **No `npm install` required.** All Node.js dependencies are vendored in the package.

3. Configure your test environment in `config/test.exs`:

```elixir
config :phoenix_test, otp_app: :my_app
```

4. Write a test:

```elixir
defmodule MyApp.FeatureTest do
  use ExUnit.Case, async: true
  import PhoenixTest

  @endpoint MyApp.Endpoint

  test "homepage has a welcome heading", %{conn: conn} do
    conn
    |> visit("/")
    |> assert_has("h1", text: "Welcome")
  end
end
```

5. Run it:

```bash
mix test
```

## Installation

Add to your dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:phoenix_test_jsdom, "~> 0.1.0"}
  ]
end
```

All Node.js dependencies (JSDom, etc.) are bundled into a single file and shipped with the hex package — no `npm install` step is needed.

## Usage

```elixir
import PhoenixTest

test "navigates to about page", %{conn: conn} do
  conn
  |> visit("/")
  |> click_link("About")
  |> assert_has("h1", text: "About Us")
end

test "submits a form", %{conn: conn} do
  conn
  |> visit("/contact")
  |> fill_in("Name", with: "Aragorn")
  |> select("Elessar", from: "Aliases")
  |> choose("Human")
  |> check("Ranger")
  |> click_button("Submit")
  |> assert_has(".success", text: "Thanks!")
end

test "LiveView interactions", %{conn: conn} do
  conn
  |> visit("/counter")
  |> click_button("Increment")
  |> click_button("Increment")
  |> assert_has("h1", text: "Counter: 2")
end

test "assertions", %{conn: conn} do
  conn
  |> visit("/page")
  |> assert_has("h1", text: "Welcome")
  |> refute_has(".error")
  |> assert_path("/page")
end
```

## Configuration

Set a custom Node.js binary path:

```elixir
config :phoenix_test_jsdom, node_path: "/path/to/node"
```

## Test Setup

In your test case module:

```elixir
defmodule MyApp.FeatureTest do
  use ExUnit.Case, async: true
  import PhoenixTest

  @endpoint MyApp.Endpoint

  test "example", %{conn: conn} do
    conn
    |> visit("/")
    |> assert_has("h1", text: "Welcome")
  end
end
```

In your `test/test_helper.exs`:

```elixir
{:ok, _} = Supervisor.start_link(
  [{Phoenix.PubSub, name: MyApp.PubSub}],
  strategy: :one_for_one
)
{:ok, _} = MyApp.Endpoint.start_link()
ExUnit.start()
```

## Architecture

```text
Test Process --> Session --> PhoenixTest.Driver protocol
                  |
                  +--> Static pages: Plug.Conn dispatch
                  +--> LiveView pages: PhoenixTest.Live driver
                  +--> JSDom bridge: Node.js process via Port
                       (DOM queries, HTML parsing)
```

The library manages a persistent Node.js process that hosts JSDom instances. Each test can create isolated JSDom instances identified by unique IDs, enabling fully async test execution.

## Development

The Node.js server (`priv/server.js`) and its dependencies are bundled into a single file using Vite library mode. After modifying `priv/server.js`:

```bash
cd priv
npm install   # only needed once, or after changing dependencies
npm run bundle
```

This produces `priv/dist/server.bundle.js` which must be committed to the repository.
