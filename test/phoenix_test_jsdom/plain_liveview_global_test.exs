defmodule PhoenixTestJsdom.PlainLiveViewGlobalTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint PhoenixTestJsdom.TestEndpoint

  alias PhoenixTestJsdom.{Jsdom, Session}

  setup do
    conn = build_conn()
    session = Session.new(@endpoint)
    {:ok, conn: conn, session: session}
  end

  describe "plain Phoenix.LiveViewTest (no JS)" do
    test "mounts counter and increments with standard LiveView helpers", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/counter")
      view |> element("button", "Increment") |> render_click()
      assert has_element?(view, "h1", "Counter: 1")
    end

    test "multiple clicks update server state", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/counter")
      view |> element("button", "Increment") |> render_click()
      view |> element("button", "Increment") |> render_click()
      view |> element("button", "Decrement") |> render_click()
      assert has_element?(view, "h1", "Counter: 1")
    end
  end

  describe "JSDom path (JS hooks execute)" do
    test "React hook increments count", %{session: session} do
      id = Session.gen_id()
      :ok = Jsdom.visit(id, session.base_url <> "/react-counter")
      :ok = Jsdom.click_button(id, nil, "Increment", nil)
      {:ok, html} = Jsdom.get_html(id)
      assert html =~ "Count: 1"
    end

    test "multiple React hook clicks accumulate", %{session: session} do
      id = Session.gen_id()
      :ok = Jsdom.visit(id, session.base_url <> "/react-counter")
      :ok = Jsdom.click_button(id, nil, "Increment", nil)
      :ok = Jsdom.click_button(id, nil, "Increment", nil)
      :ok = Jsdom.click_button(id, nil, "Decrement", nil)
      {:ok, html} = Jsdom.get_html(id)
      assert html =~ "Count: 1"
    end
  end

  describe "mixed: LiveViewTest and JSDom in the same test" do
    test "standard LV handles server events; JSDom handles JS hooks", %{
      conn: conn,
      session: session
    } do
      {:ok, view, _} = live(conn, "/counter")
      view |> element("button", "Increment") |> render_click()
      assert has_element?(view, "h1", "Counter: 1")

      id = Session.gen_id()
      :ok = Jsdom.visit(id, session.base_url <> "/react-counter")
      :ok = Jsdom.click_button(id, nil, "Decrement", nil)
      {:ok, html} = Jsdom.get_html(id)
      assert html =~ "Count: -1"
    end
  end
end
