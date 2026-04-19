defmodule PhoenixTestJsdom.FireEvent do
  @moduledoc """
  Fires DOM events on elements inside a JSDom-mounted LiveView, mirroring
  [dom-testing-library](https://github.com/testing-library/dom-testing-library)'s
  `fireEvent.<eventName>` API.

  Event names are extracted at compile time directly from the installed
  `@testing-library/dom` package (via a short Node invocation), so the list
  stays in sync automatically with whichever version is in `priv/node_modules`.

  ## Usage

      import Phoenix.LiveViewTest, only: [element: 2, element: 3]
      alias PhoenixTestJsdom.FireEvent

      view
      |> FireEvent.mouse_down(element(view, "button#menu"))
      |> FireEvent.key_down(element(view, "input"), %{key: "Enter", code: "Enter"})
      |> FireEvent.change(element(view, "input[name=email]"), %{target: %{value: "a@b.com"}})
      |> PhoenixTestJsdom.render()

  The third argument merges on top of the event's `defaultInit`. The special
  key `:target` (a map) is applied as element property assignments *before*
  dispatch, which is how RTL's `change(el, { target: { value: "x" } })` works.

  All functions return the `view` for pipeability. Use `PhoenixTestJsdom.render/1`
  afterwards to see the updated HTML.

  For custom or non-standard events, use the generic `fire/4`:

      FireEvent.fire(view, element(view, "#my-el"), "my-custom-event", %{detail: 42})

  ## Attribution

  Event names and defaults are taken from
  [dom-testing-library](https://github.com/testing-library/dom-testing-library)
  (MIT License, Copyright (c) 2018 Kent C. Dodds).
  """

  alias PhoenixTestJsdom.{Jsdom, ViewRegistry}
  alias Phoenix.LiveViewTest.{View, Element}

  # --- Compile-time event list extraction ---
  #
  # We shell out to Node once, in `priv/` (so require() resolves
  # `@testing-library/dom`), and parse the event keys from stdout. No
  # intermediate JSON file.

  @priv_dir Path.expand("../../priv", __DIR__)
  @external_resource Path.join([
                       @priv_dir,
                       "node_modules",
                       "@testing-library",
                       "dom",
                       "dist",
                       "event-map.js"
                     ])

  @node_script """
  const { eventMap, eventAliasMap } = require("@testing-library/dom/dist/event-map");
  const out = [];
  for (const key of Object.keys(eventMap)) out.push(key);
  for (const alias of Object.keys(eventAliasMap)) out.push(alias);
  process.stdout.write(JSON.stringify(out));
  """

  @events (case System.cmd("node", ["-e", @node_script], cd: @priv_dir, stderr_to_stdout: true) do
             {json, 0} ->
               Jason.decode!(json)

             {output, status} ->
               raise "Failed to extract event map from @testing-library/dom " <>
                       "(exit #{status}). Make sure Node is installed and " <>
                       "`npm install` has been run in #{inspect(@priv_dir)}.\n\n" <>
                       output
           end)

  for rtl_key <- @events do
    fn_name = rtl_key |> Macro.underscore() |> String.to_atom()

    def unquote(fn_name)(%View{} = view, %Element{} = element, properties \\ %{}),
      do: fire(view, element, unquote(rtl_key), properties)
  end

  @doc """
  Fires an arbitrary named DOM event on the resolved element.

  Useful for custom events or any event not in dom-testing-library's event map.
  """
  def fire(
        %View{} = view,
        %Element{selector: sel, text_filter: tf},
        event_name,
        properties \\ %{}
      ) do
    id = ViewRegistry.fetch!(view)

    case Jsdom.fire_event(id, sel, tf, to_string(event_name), properties) do
      :ok ->
        view

      {:error, msg} ->
        raise "PhoenixTestJsdom.FireEvent.#{event_name} failed on #{inspect(sel)}: #{msg}"
    end
  end
end
