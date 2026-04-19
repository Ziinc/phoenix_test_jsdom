defmodule PhoenixTestJsdomTest do
  use ExUnit.Case, async: true
  import PhoenixTest
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint PhoenixTestJsdom.TestEndpoint

  setup do
    {:ok,
     session: PhoenixTestJsdom.Session.new(PhoenixTestJsdom.TestEndpoint),
     conn: build_conn()}
  end

  describe "react liveview counter" do
    test "renders React counter with initial count 0", %{session: session} do
      session
      |> visit("/react-counter")
      |> assert_has("#count-display", text: "Count: 0")
      |> assert_has("p", text: "hello from react liveview")
    end

    test "clicking Increment pushes event to LiveView and updates count", %{session: session} do
      session
      |> visit("/react-counter")
      |> click_button("Increment")
      |> assert_has("#count-display", text: "Count: 1")
      |> assert_has("p", text: "hello from react liveview")
    end

    test "clicking Decrement pushes event to LiveView and updates count", %{session: session} do
      session
      |> visit("/react-counter")
      |> click_button("Decrement")
      |> assert_has("#count-display", text: "Count: -1")
      |> assert_has("p", text: "hello from react liveview")
    end

    test "multiple interactions accumulate", %{session: session} do
      session
      |> visit("/react-counter")
      |> click_button("Increment")
      |> click_button("Increment")
      |> click_button("Increment")
      |> click_button("Decrement")
      |> assert_has("#count-display", text: "Count: 2")
    end
  end

  describe "react static counter" do
    test "renders React counter with initial count 0", %{session: session} do
      session
      |> visit("/react-counter-static")
      |> assert_has("#count-display", text: "Count: 0")
      |> assert_has("p", text: "hello from react static")
    end

    test "clicking Decrement from 0 gives -1", %{session: session} do
      session
      |> visit("/react-counter-static")
      |> click_button("Decrement")
      |> assert_has("#count-display", text: "Count: -1")
      |> assert_has("p", text: "hello from react static")
    end

    test "mixed increment and decrement", %{session: session} do
      session
      |> visit("/react-counter-static")
      |> click_button("Increment")
      |> click_button("Increment")
      |> click_button("Increment")
      |> click_button("Decrement")
      |> assert_has("#count-display", text: "Count: 2")
      |> assert_has("p", text: "hello from react static")
    end
  end

  describe "reseed patch" do
    test "plain JS variables on window survive reseed", %{conn: conn} do
      {:ok, view, _} = live(conn, "/counter") |> PhoenixTestJsdom.mount()

      {:ok, _} = PhoenixTestJsdom.exec_js(view, "window.__seed = 42; window.__seed")

      PhoenixTestJsdom.render_click(view, selector: "button", text: "Increment")

      assert {:ok, "42"} = PhoenixTestJsdom.exec_js(view, "window.__seed")
    end

    test "React component state survives reseed (phx-update=ignore element preserved in place)", %{conn: conn} do
      {:ok, view, _} = live(conn, "/react-counter") |> PhoenixTestJsdom.mount()

      view |> PhoenixTestJsdom.click("Increment", selector: "button")
      assert PhoenixTestJsdom.render(view) =~ "Count: 1"

      {:ok, _} =
        PhoenixTestJsdom.exec_js(
          view,
          "document.getElementById('react-root').__sentinel__ = 'alive'; 'ok'"
        )

      PhoenixTestJsdom.render_async(view)

      assert {:ok, "alive"} =
               PhoenixTestJsdom.exec_js(view, "document.getElementById('react-root').__sentinel__")

      assert PhoenixTestJsdom.render(view) =~ "Count: 1"
    end

    test "LiveViewTest interop functions work correctly after patched reseed", %{conn: conn} do
      {:ok, view, _} = live(conn, "/counter") |> PhoenixTestJsdom.mount()

      PhoenixTestJsdom.render_click(view, selector: "button", text: "Increment")

      assert render(view) =~ "Counter: 1"

      view |> element("button", "Increment") |> render_click()
      assert render(view) =~ "Counter: 2"

      PhoenixTestJsdom.render_click(view, selector: "button", text: "Increment")
      assert PhoenixTestJsdom.render(view) =~ "Counter: 3"
    end
  end
end
