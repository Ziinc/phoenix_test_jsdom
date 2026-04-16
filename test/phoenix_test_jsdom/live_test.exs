defmodule PhoenixTestJsdom.LiveTest do
  use ExUnit.Case, async: true
  import PhoenixTest

  alias PhoenixTestJsdom.Session

  setup do
    {:ok, session: Session.new(PhoenixTestJsdom.TestEndpoint)}
  end

  test "visits a LiveView page and sees content", %{session: session} do
    session
    |> visit("/counter")
    |> assert_has("h1", text: "Counter: 0")
  end

  test "click_button with phx-click triggers LiveView event", %{session: session} do
    session
    |> visit("/counter")
    |> click_button("Increment")
    |> assert_has("h1", text: "Counter: 1")
  end

  test "fill_in and submit triggers phx-submit", %{session: session} do
    session
    |> visit("/counter")
    |> fill_in("Name", with: "Aragorn")
    |> click_button("Set Name")
    |> assert_has("p", text: "Hello, Aragorn!")
  end

  test "multiple interactions update state", %{session: session} do
    session
    |> visit("/counter")
    |> click_button("Increment")
    |> click_button("Increment")
    |> click_button("Decrement")
    |> assert_has("h1", text: "Counter: 1")
  end
end
