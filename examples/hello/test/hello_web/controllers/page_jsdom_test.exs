defmodule HelloWeb.PageJsdomTest do
  use HelloWeb.ConnCase, async: false

  import PhoenixTest

  alias PhoenixTestJsdom.Session

  setup_all do
    start_supervised(PhoenixTestJsdom)
    :ok
  end
  describe "via PhoenixTest" do

      setup do
        {:ok, session: Session.new(@endpoint)}
      end

    test "home page renders welcome copy", %{session: session} do
      session
      |> visit("/")
      |> assert_has("*", text: "Peace of mind from prototype to production")
    end

    test "clicking Increment button updates the counter via JSDom JS execution", %{session: session} do
      session
      |> visit("/")
      |> assert_has("#count", text: "0")
      |> click_button("Increment")
      |> assert_has("#count", text: "1")
      |> click_button("Increment")
      |> assert_has("#count", text: "2")
    end

  end
end
