defmodule PhoenixTestJsdom.InteractionsTest do
  use ExUnit.Case, async: true
  import PhoenixTest

  alias PhoenixTestJsdom.Session

  setup do
    {:ok, session: Session.new(PhoenixTestJsdom.TestEndpoint)}
  end

  describe "click_link" do
    test "navigates to the linked page", %{session: session} do
      session
      |> visit("/")
      |> click_link("About")
      |> assert_has("h1", text: "About Us")
    end

    test "navigates with selector", %{session: session} do
      session
      |> visit("/")
      |> click_link("a", "About")
      |> assert_has("h1", text: "About Us")
    end
  end

  describe "fill_in and submit" do
    test "fills in a text field and submits the form", %{session: session} do
      session
      |> visit("/form")
      |> fill_in("Name", with: "Aragorn")
      |> click_button("Submit")
      |> assert_has("h1", text: "Thanks, Aragorn!")
    end
  end

  describe "select" do
    test "selects an option", %{session: session} do
      session
      |> visit("/form")
      |> select("Role", option: "Admin")
      |> click_button("Submit")
      |> assert_path("/submit")
    end
  end

  describe "check" do
    test "checks a checkbox", %{session: session} do
      session
      |> visit("/form")
      |> check("I agree")
      |> click_button("Submit")
      |> assert_path("/submit")
    end
  end

  describe "choose" do
    test "selects a radio button", %{session: session} do
      session
      |> visit("/form")
      |> choose("Blue")
      |> click_button("Submit")
      |> assert_path("/submit")
    end
  end

  describe "within" do
    test "scopes assertions to a selector", %{session: session} do
      session
      |> visit("/form")
      |> within("form", fn s ->
        s |> assert_has("label", text: "Name")
      end)
    end
  end
end
