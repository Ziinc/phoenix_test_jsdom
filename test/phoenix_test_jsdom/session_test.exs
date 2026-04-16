defmodule PhoenixTestJsdom.SessionTest do
  use ExUnit.Case, async: true
  import PhoenixTest

  alias PhoenixTest.Driver
  alias PhoenixTestJsdom.Session

  setup do
    {:ok, session: Session.new(PhoenixTestJsdom.TestEndpoint)}
  end

  test "visit renders the page", %{session: session} do
    session = visit(session, "/")
    assert Driver.render_html(session) |> LazyHTML.to_html() =~ "Welcome"
  end

  test "render_page_title returns the title", %{session: session} do
    session = visit(session, "/")
    assert Driver.render_page_title(session) == "Test Page"
  end

  test "current_path returns the visited path", %{session: session} do
    session = visit(session, "/")
    assert Driver.current_path(session) == "/"
  end

  test "assert_has finds an element", %{session: session} do
    session
    |> visit("/")
    |> assert_has("h1", text: "Welcome")
  end

  test "assert_has raises for missing element", %{session: session} do
    session = visit(session, "/")

    assert_raise ExUnit.AssertionError, fn ->
      assert_has(session, "h2", text: "Missing")
    end
  end

  test "refute_has passes for missing element", %{session: session} do
    session
    |> visit("/")
    |> refute_has("h2", text: "Missing")
  end

  test "refute_has raises for present element", %{session: session} do
    session = visit(session, "/")

    assert_raise ExUnit.AssertionError, fn ->
      refute_has(session, "h1", text: "Welcome")
    end
  end

  test "assert_path passes for correct path", %{session: session} do
    session
    |> visit("/about")
    |> assert_path("/about")
  end

  test "refute_path passes for different path", %{session: session} do
    session
    |> visit("/about")
    |> refute_path("/")
  end
end
