defmodule PhoenixTestJsdom do
  @moduledoc """
  A [PhoenixTest](https://hexdocs.pm/phoenix_test) driver that uses JSDom for
  lightweight headless browser testing of Phoenix applications.

  ## Overview

  PhoenixTestJsdom provides a `PhoenixTest.Driver` implementation backed by
  [JSDom](https://github.com/jsdom/jsdom) — a pure-JavaScript DOM implementation
  for Node.js. This gives you real DOM fidelity without requiring a full browser.

  For static pages, the driver handles HTTP requests and form interactions
  directly via `Plug.Conn`. For LiveView pages, it delegates to PhoenixTest's
  built-in LiveView driver, providing seamless support for both page types.

  ## Setup

  Add to your dependencies:

      {:phoenix_test_jsdom, "~> 0.1.0"}

  Install Node.js dependencies in your project's `priv/` directory:

      cd priv && npm install

  ## Usage

  Create a session and use the standard PhoenixTest API:

      import PhoenixTest

      session = PhoenixTestJsdom.Session.new(MyApp.Endpoint)

      session
      |> visit("/")
      |> click_link("About")
      |> assert_has("h1", text: "About Us")

  Forms work as expected:

      session
      |> visit("/contact")
      |> fill_in("Name", with: "Aragorn")
      |> select("Role", option: "Admin")
      |> click_button("Submit")
      |> assert_has("h1", text: "Thanks, Aragorn!")

  LiveView pages are automatically detected and fully supported:

      session
      |> visit("/counter")
      |> click_button("Increment")
      |> assert_has("h1", text: "Counter: 1")

  ## Configuration

  Set a custom Node.js binary path if needed:

      config :phoenix_test_jsdom, node_path: "/path/to/node"
  """
end
