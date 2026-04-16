defmodule PhoenixTestJsdomTest do
  use ExUnit.Case, async: true
  import PhoenixTest

  setup do
    {:ok, session: PhoenixTestJsdom.Session.new(PhoenixTestJsdom.TestEndpoint)}
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
end
