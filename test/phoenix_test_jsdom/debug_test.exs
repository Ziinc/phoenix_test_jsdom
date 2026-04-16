defmodule PhoenixTestJsdom.DebugTest do
  use ExUnit.Case, async: true

  import PhoenixTest
  alias PhoenixTestJsdom.Jsdom
  alias PhoenixTestJsdom.Session

  setup do
    {:ok, session: Session.new(PhoenixTestJsdom.TestEndpoint)}
  end

  test "should be able to inspect jsdom HTML and JS-rendered elements", %{session: session} do
    session = visit(session, "/react-counter-static")
    :ok = Jsdom.wait_for_selector(session.instance_id, "#count-display", 2000)

    {:ok, html} = Jsdom.get_html(session.instance_id)
    assert html =~ ~s(id="count-display")
    assert html =~ "Count: 0"
    assert html =~ "hello from react static"

    within(session, "#app", fn s ->
      s
      |> assert_has("#count-display", text: "Count: 0")
      |> assert_has("p", text: "hello from react static")
    end)
  end
end
