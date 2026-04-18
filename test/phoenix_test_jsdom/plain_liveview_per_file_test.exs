defmodule PhoenixTestJsdom.PlainLiveViewPerFileTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint PhoenixTestJsdom.TestEndpoint

  setup_all do
    start_supervised(PhoenixTestJsdom)
    :ok
  end

  setup do
    {:ok, conn: build_conn()}
  end

  test "React hook runs after per-file startup", %{conn: conn} do
    {:ok, view, _} = live(conn, "/react-counter") |> PhoenixTestJsdom.mount()

    html =
      view
      |> PhoenixTestJsdom.click("Increment", selector: "button")
      |> PhoenixTestJsdom.render()

    assert html =~ "Count: 1"
  end


  test "can interop with plain LiveViewTest", %{conn: conn} do
    # Mount the counter into JSDom so client-side JS executes alongside LiveViewTest.
    {:ok, view, _} = live(conn, "/counter") |> PhoenixTestJsdom.mount()

    # render_click sends the server event via Phoenix.LiveViewTest AND reseeds JSDom with
    # the resulting HTML — both server and client stay in sync.
    PhoenixTestJsdom.render_click(view, selector: "button", text: "Increment")

    # Phoenix.LiveViewTest.render/1 (unqualified — imported above) shows server state.
    assert render(view) =~ "Counter: 1"
  end


  test "plain LiveViewTest works alongside JSDom after per-file startup", %{conn: conn} do
    {:ok, view, _} = live(conn, "/counter")
    view |> element("button", "Increment") |> render_click()
    assert has_element?(view, "h1", "Counter: 1")
  end
end
