defmodule PhoenixTestJsdom.JsdomTest do
  use ExUnit.Case, async: true

  alias PhoenixTestJsdom.Jsdom

  test "ping responds" do
    assert {:ok, "pong"} = Jsdom.ping()
  end

  test "create and get_html round-trips HTML" do
    id = gen_id()
    html = "<html><head></head><body><h1>Hello</h1></body></html>"
    assert :ok = Jsdom.create(id, html)
    assert {:ok, result} = Jsdom.get_html(id)
    assert result =~ "<h1>Hello</h1>"
    Jsdom.destroy(id)
  end

  test "get_title returns the title" do
    id = gen_id()
    Jsdom.create(id, "<html><head><title>My Page</title></head><body></body></html>")
    assert {:ok, "My Page"} = Jsdom.get_title(id)
    Jsdom.destroy(id)
  end

  test "query finds element by selector" do
    id = gen_id()
    Jsdom.create(id, "<html><head></head><body><h1>Hello</h1><p>World</p></body></html>")
    assert {:ok, %{"found" => true, "text" => "Hello"}} = Jsdom.query(id, "h1", nil, nil)
    assert {:ok, %{"found" => true, "text" => "World"}} = Jsdom.query(id, "p", nil, nil)
    assert {:ok, %{"found" => false}} = Jsdom.query(id, "h2", nil, nil)
    Jsdom.destroy(id)
  end

  test "query matches text content" do
    id = gen_id()
    Jsdom.create(id, "<html><head></head><body><p>foo</p><p>bar</p></body></html>")
    assert {:ok, %{"found" => true, "text" => "bar"}} = Jsdom.query(id, "p", "bar", nil)
    assert {:ok, %{"found" => false}} = Jsdom.query(id, "p", "baz", nil)
    Jsdom.destroy(id)
  end

  test "query respects within scope" do
    id = gen_id()

    Jsdom.create(id, """
    <html><head></head><body>
      <div id="a"><p>inside</p></div>
      <div id="b"><p>outside</p></div>
    </body></html>
    """)

    assert {:ok, %{"found" => true, "text" => "inside"}} = Jsdom.query(id, "p", nil, "#a")
    assert {:ok, %{"found" => true, "text" => "outside"}} = Jsdom.query(id, "p", nil, "#b")
    assert {:ok, %{"found" => false}} = Jsdom.query(id, "p", "outside", "#a")
    Jsdom.destroy(id)
  end

  test "destroy cleans up instance" do
    id = gen_id()
    Jsdom.create(id, "<html><head></head><body></body></html>")
    assert :ok = Jsdom.destroy(id)
    assert {:error, _} = Jsdom.get_html(id)
  end

  defp gen_id, do: :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
end
