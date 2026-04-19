defmodule PhoenixTestJsdom.FireEventTest do
  use ExUnit.Case, async: true
  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias PhoenixTestJsdom.FireEvent

  @endpoint PhoenixTestJsdom.TestEndpoint

  setup_all do
    start_supervised(PhoenixTestJsdom)
    :ok
  end

  setup do
    {:ok, conn: build_conn()}
  end

  describe "codegen sanity" do
    test "generates 3-arity functions for all event-map entries" do
      fns = FireEvent.__info__(:functions) |> Enum.filter(fn {_, a} -> a == 3 end)
      assert length(fns) >= 91
    end

    test "generates expected event functions" do
      for name <- [
            :click,
            :change,
            :input,
            :key_down,
            :key_up,
            :key_press,
            :mouse_down,
            :mouse_up,
            :mouse_move,
            :mouse_over,
            :mouse_out,
            :mouse_enter,
            :mouse_leave,
            :focus,
            :blur,
            :focus_in,
            :focus_out,
            :dbl_click,
            :double_click,
            :context_menu,
            :drag,
            :drag_start,
            :drag_end,
            :drag_enter,
            :drag_leave,
            :drag_over,
            :drop,
            :copy,
            :cut,
            :paste,
            :composition_start,
            :composition_update,
            :composition_end,
            :touch_start,
            :touch_end,
            :touch_move,
            :touch_cancel,
            :pointer_down,
            :pointer_up,
            :pointer_move,
            :scroll,
            :wheel,
            :select,
            :submit,
            :reset,
            :invalid
          ] do
        assert function_exported?(FireEvent, name, 3),
               "expected FireEvent.#{name}/3 to be exported"
      end
    end

    test "fire/3 and fire/4 are exported" do
      assert function_exported?(FireEvent, :fire, 3)
      assert function_exported?(FireEvent, :fire, 4)
    end
  end

  describe "click" do
    test "click via FireEvent triggers phx-click → server state update", %{conn: conn} do
      {:ok, view, _} = live(conn, "/counter") |> PhoenixTestJsdom.mount()

      view
      |> FireEvent.click(element(view, "button", "Increment"))

      assert PhoenixTestJsdom.render(view) =~ "Counter: 1"
    end

    test "multiple clicks accumulate", %{conn: conn} do
      {:ok, view, _} = live(conn, "/counter") |> PhoenixTestJsdom.mount()

      view
      |> FireEvent.click(element(view, "button", "Increment"))
      |> FireEvent.click(element(view, "button", "Increment"))
      |> FireEvent.click(element(view, "button", "Decrement"))

      assert PhoenixTestJsdom.render(view) =~ "Counter: 1"
    end
  end

  describe "change with target" do
    test "change with target.value fills a text input and submitting reflects new name", %{
      conn: conn
    } do
      {:ok, view, _} = live(conn, "/counter") |> PhoenixTestJsdom.mount()

      view
      |> FireEvent.change(element(view, "input[name=name]"), %{"target" => %{"value" => "Alice"}})
      |> FireEvent.click(element(view, "button", "Set Name"))

      assert PhoenixTestJsdom.render(view) =~ "Hello, Alice!"
    end
  end

  describe "keyboard events" do
    test "key_down dispatches without error", %{conn: conn} do
      {:ok, view, _} = live(conn, "/counter") |> PhoenixTestJsdom.mount()

      result =
        view
        |> FireEvent.key_down(element(view, "input[name=name]"), %{
          "key" => "Enter",
          "code" => "Enter"
        })

      assert is_struct(result, Phoenix.LiveViewTest.View)
    end

    test "key_up dispatches without error", %{conn: conn} do
      {:ok, view, _} = live(conn, "/counter") |> PhoenixTestJsdom.mount()
      result = view |> FireEvent.key_up(element(view, "input[name=name]"), %{"key" => "a"})
      assert is_struct(result, Phoenix.LiveViewTest.View)
    end
  end

  describe "mouse events" do
    test "mouse_down and mouse_up dispatch without error", %{conn: conn} do
      {:ok, view, _} = live(conn, "/counter") |> PhoenixTestJsdom.mount()

      view
      |> FireEvent.mouse_down(element(view, "button", "Increment"))
      |> FireEvent.mouse_up(element(view, "button", "Increment"))
    end

    test "mouse_move dispatches without error", %{conn: conn} do
      {:ok, view, _} = live(conn, "/counter") |> PhoenixTestJsdom.mount()

      result =
        view
        |> FireEvent.mouse_move(element(view, "button", "Increment"), %{
          "clientX" => 10,
          "clientY" => 20
        })

      assert is_struct(result, Phoenix.LiveViewTest.View)
    end
  end

  describe "focus and blur events" do
    test "focus and blur dispatch without error", %{conn: conn} do
      {:ok, view, _} = live(conn, "/counter") |> PhoenixTestJsdom.mount()

      view
      |> FireEvent.focus(element(view, "input[name=name]"))
      |> FireEvent.blur(element(view, "input[name=name]"))
    end
  end

  describe "text_filter narrowing" do
    test "text_filter selects between two same-selector buttons", %{conn: conn} do
      {:ok, view, _} = live(conn, "/counter") |> PhoenixTestJsdom.mount()

      view |> FireEvent.click(element(view, "button", "Decrement"))
      assert PhoenixTestJsdom.render(view) =~ "Counter: -1"
    end
  end

  describe "fire/4 generic dispatch" do
    test "fires a custom unmapped event without error", %{conn: conn} do
      {:ok, view, _} = live(conn, "/counter") |> PhoenixTestJsdom.mount()
      result = FireEvent.fire(view, element(view, "button", "Increment"), "my-custom-event")
      assert is_struct(result, Phoenix.LiveViewTest.View)
    end

    test "fires a standard event by string name", %{conn: conn} do
      {:ok, view, _} = live(conn, "/counter") |> PhoenixTestJsdom.mount()
      result = FireEvent.fire(view, element(view, "input[name=name]"), "focus")
      assert is_struct(result, Phoenix.LiveViewTest.View)
    end
  end

  describe "React counter" do
    test "click via FireEvent drives React onClick", %{conn: conn} do
      {:ok, view, _} = live(conn, "/react-counter") |> PhoenixTestJsdom.mount()

      view |> FireEvent.click(element(view, "button", "Increment"))

      assert PhoenixTestJsdom.render(view) =~ "Count: 1"
    end
  end
end
