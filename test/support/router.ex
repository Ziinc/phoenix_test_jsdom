defmodule PhoenixTestJsdom.TestRouter do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {PhoenixTestJsdom.TestLayout, :root})
    plug(:protect_from_forgery)
  end

  pipeline :require_user do
    plug(:require_user_session)
  end

  scope "/", PhoenixTestJsdom do
    pipe_through(:browser)
    get("/", PageController, :index)
    get("/about", PageController, :about)
    get("/form", PageController, :form)
    post("/submit", PageController, :submit)

    live("/counter", CounterLive)
    live("/react-counter", ReactCounterLive)
    get("/react-counter-static", PageController, :react_counter)
  end

  scope "/", PhoenixTestJsdom do
    pipe_through([:browser, :require_user])

    live("/protected-counter", CounterLive)
  end

  defp require_user_session(conn, _opts) do
    if Plug.Conn.get_session(conn, "user_id") do
      conn
    else
      conn
      |> Plug.Conn.send_resp(403, "Forbidden")
      |> Plug.Conn.halt()
    end
  end
end
