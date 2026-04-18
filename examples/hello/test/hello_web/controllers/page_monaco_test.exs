defmodule HelloWeb.PageMonacoTest do
  use HelloWeb.ConnCase, async: false

  import PhoenixTest

  alias PhoenixTestJsdom.{Jsdom, Session}

  @editor_selector "#monaco-editor .monaco-editor"
  @inputarea_selector "#monaco-editor .inputarea"

  setup do
    {:ok, session: Session.new(@endpoint)}
  end

  test "monaco editor mounts on the home page", %{session: session} do
    session
    |> visit("/")
    |> PhoenixTestJsdom.wait_for(@editor_selector, 10_000)
    |> assert_has("#monaco-editor")
  end

  test "typing into the editor updates the model value", %{session: session} do
    session = session |> visit("/")
    :ok = Jsdom.wait_for_selector(session.instance_id, @inputarea_selector, 10_000)

    session
    |> PhoenixTestJsdom.type("hello world", selector: @inputarea_selector)

    {:ok, value} = PhoenixTestJsdom.exec_js(session, "window.__monacoEditor.getValue()")
    :timer.sleep(500)
    assert value == "hello world"
  end

  test "multi-line typing inserts newlines", %{session: session} do
    session = session |> visit("/")
    :ok = Jsdom.wait_for_selector(session.instance_id, @inputarea_selector, 10_000)

    session
    |> PhoenixTestJsdom.type("line 1", selector: @inputarea_selector)
    |> PhoenixTestJsdom.type("\nline 2", selector: @inputarea_selector)

    {:ok, value} = PhoenixTestJsdom.exec_js(session, "window.__monacoEditor.getValue()")
    assert value == "line 1\nline 2"

    {:ok, line_count} =
      PhoenixTestJsdom.exec_js(session, "window.__monacoEditor.getModel().getLineCount()")

    assert line_count == "2"
  end

  test "clearing and retyping produces correct value", %{session: session} do
    session = session |> visit("/")
    :ok = Jsdom.wait_for_selector(session.instance_id, @inputarea_selector, 10_000)

    session
    |> PhoenixTestJsdom.type("initial", selector: @inputarea_selector)

    {:ok, _} = PhoenixTestJsdom.exec_js(session, "window.__monacoEditor.setValue('')")

    session
    |> PhoenixTestJsdom.type("replaced", selector: @inputarea_selector)

    {:ok, value} = PhoenixTestJsdom.exec_js(session, "window.__monacoEditor.getValue()")
    assert value == "replaced"
  end
end
