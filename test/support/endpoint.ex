defmodule PhoenixTestJsdom.TestEndpoint do
  use Phoenix.Endpoint, otp_app: :phoenix_test_jsdom

  @session_options [
    store: :cookie,
    key: "_test_key",
    signing_salt: "test_salt"
  ]

  socket("/live", Phoenix.LiveView.Socket, websocket: [connect_info: [session: @session_options]])

  plug(Plug.Static, at: "/assets/phoenix", from: {:phoenix, "priv/static"}, only: ~w(phoenix.js))

  plug(Plug.Static,
    at: "/assets/react",
    from: {:phoenix_test_jsdom, "priv/node_modules/react/umd"},
    only: ~w(react.development.js)
  )

  plug(Plug.Static,
    at: "/assets/react-dom",
    from: {:phoenix_test_jsdom, "priv/node_modules/react-dom/umd"},
    only: ~w(react-dom.development.js)
  )

  plug(Plug.Static,
    at: "/assets/lv",
    from: {:phoenix_live_view, "priv/static"},
    only: ~w(phoenix_live_view.js)
  )

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart],
    pass: ["*/*"]
  )

  plug(Plug.Session, @session_options)

  plug(PhoenixTestJsdom.TestRouter)
end
