defmodule PhoenixTestJsdom do
  @moduledoc """
  A view-centric JSDom bridge for Phoenix LiveView testing.

  Mount a live view into a JSDom instance so client-side JavaScript (React
  hooks, etc.) executes alongside the live server-side process:

      {:ok, view, _html} = live(conn, "/react-counter")
      view = PhoenixTestJsdom.mount(view)

      html =
        view
        |> PhoenixTestJsdom.click("Increment", selector: "button")
        |> PhoenixTestJsdom.render()

      assert html =~ "Count: 1"

  Or use the pass-through tuple form:

      {:ok, view, html} = live(conn, "/react-counter") |> PhoenixTestJsdom.mount()

  ## Interaction functions

  All interaction functions return the view so you can pipe them:

      view
      |> PhoenixTestJsdom.click("Submit")
      |> PhoenixTestJsdom.render()

  The `render_*` variants mirror `Phoenix.LiveViewTest.render_*` names and
  return the HTML string directly, for compatibility with existing assertions:

      html = PhoenixTestJsdom.render_click(view, "button", "Increment")
      assert html =~ "Count: 1"

  ## Isolated LiveComponents

  Render a standalone LiveComponent into JSDom without a live URL:

      view = PhoenixTestJsdom.mount(MyComponent, %{id: "c", value: 0},
               endpoint: MyAppWeb.Endpoint)
      assert PhoenixTestJsdom.render(view) =~ "value=\\"0\\""

  ## Configuration

  Settings can be passed when starting the supervision tree (`start_link/1` or `start/1`) **or** via `config :phoenix_test_jsdom, ...` in `config/test.exs`. Runtime options override application config for `:setup_files` and `:cwd`.

  | Option | Scope | Purpose |
  |--------|--------|---------|
  | `node_path` | Application config only | Absolute path to the Node binary. If unset, the worker tries `mise which node`, then `node` on `PATH`. |
  | `setup_files` | Start options or config | List of CommonJS module paths (or a single string path) executed in each new JSDom window—polyfills, global mocks, test setup (similar to Vitest `setupFiles`). |
  | `cwd` | Start options or config | Working directory for the Node process. Use this when scripts or `require()` must resolve packages from your app (for example your own `node_modules`). |

  ```elixir
  # config/test.exs
  config :phoenix_test_jsdom,
    node_path: "/opt/homebrew/bin/node",
    setup_files: [Path.expand("test/support/jsdom_setup.cjs", __DIR__)],
    cwd: Path.expand("../assets", __DIR__)
  ```

  ```elixir
  # test/test_helper.exs — same keys as keyword list
  {:ok, _} =
    PhoenixTestJsdom.start_link(
      setup_files: [Path.expand("test/support/jsdom_setup.cjs", __DIR__)],
      cwd: Path.expand("../assets", __DIR__)
    )

  ExUnit.start()
  ```

  ### Setup modes (global vs per-file)

  **Global (recommended)** — start once before `ExUnit.start/0` so every test module shares one Node worker and request queue, while each mounted view or `PhoenixTestJsdom.Session` still gets its own JSDom instance id.

  ```elixir
  # test/test_helper.exs
  {:ok, _} = PhoenixTestJsdom.start()
  ExUnit.start()
  ```

  `start/0` is a thin alias over `start_link/1`; you can pass options to either.

  **Per-file (or per-module)** — start the supervisor under the test supervisor when only some tests need JSDom, or when you need different `setup_files` / `cwd` per test module (each `setup_all` run gets its own tree—heavier than global).

  ```elixir
  defmodule MyApp.HeavyJsTest do
    use ExUnit.Case, async: true
    use MyAppWeb.ConnCase

    setup_all do
      start_supervised(PhoenixTestJsdom)
      :ok
    end

    # ...
  end
  ```

  Use **global** for the usual case (`async: true` across the suite). Use **per-file** when isolating optional JS-heavy tests or varying Node options.

  ### Async & isolation model

  - **One** long-lived Node process (Erlang port) runs the bundled server; it multiplexes concurrent RPCs by request id.
  - **Each** `mount/1` (LiveView) or `Session.new/1` (PhoenixTest) allocates a **separate** JSDom instance id, stored in `PhoenixTestJsdom.ViewRegistry` keyed by `{test_pid, view_id}`. Parallel async tests do not share DOM state.
  - After server-driven updates (`render_click/2`, `render_patch/2`, `render_async/2`, etc.), HTML is **re-seeded** into the same JSDom id so the client bundle matches the LiveView-rendered markup. Pure client state that is not in the HTML snapshot is reset on each reseed—see the README note on LiveViewTest interop.

  **Waiting for client-rendered DOM** — heavy widgets (Monaco, charts) often appear after `mount/1` returns. Block on a stable selector before asserting:

  ```elixir
  {:ok, view, _} = live(conn, "/editor") |> PhoenixTestJsdom.mount()

  view
  |> PhoenixTestJsdom.wait_for(".monaco-editor", 10_000)
  |> PhoenixTestJsdom.render()
  ```

  With `PhoenixTestJsdom.Session` (PhoenixTest driver), `wait_for/3` returns the session for piping. The default timeout is 5000 ms. Lower-level callers can use `PhoenixTestJsdom.Jsdom.wait_for_selector/3` with an instance id (see the debug tests).

  ## User interactions & event firing

  **LiveView + pipable helpers** (`PhoenixTestJsdom` on `%Phoenix.LiveViewTest.View{}`) dispatch real DOM events inside JSDom: `click/3`, `click_link/3`, `fill_in/3`, `select/3`, `check/3`, `uncheck/3`, `choose/3`, `submit/2`, `type/3`, etc. Options commonly include `:selector`, `:within`, and label-based matching as in PhoenixTest.

  **Low-level DOM events** — `PhoenixTestJsdom.FireEvent` mirrors many DOM event names (`click/3`, `change/3`, `key_down/3`, …) and takes a `Phoenix.LiveViewTest.Element` from `element/2` or `element/3`. Use this when you need precise `Event` fields or events not wrapped by the pipable API.

  Examples:

  - [FireEvent and DOM coverage](https://github.com/tzeyiing/phoenix_test_jsdom/blob/main/test/phoenix_test_jsdom/fire_event_test.exs)
  - [PhoenixTest session interactions](https://github.com/tzeyiing/phoenix_test_jsdom/blob/main/test/phoenix_test_jsdom/interactions_test.exs)
  - [Per-file startup + `render_click` interop](https://github.com/tzeyiing/phoenix_test_jsdom/blob/main/test/phoenix_test_jsdom/plain_liveview_per_file_test.exs)

  ## Using with LiveViewTest

  ### Using with LiveView Components

  ## Using with PhoenixTest

  ## Advanced

  ### Executing Custom JS

  ### Triggering custom events

  ### Mounting React components

  ### Using to render web pages

  ### Adding shims/stubs with setup files

  """

  alias PhoenixTestJsdom.{Jsdom, ViewRegistry}
  alias Phoenix.LiveViewTest
  require Phoenix.LiveViewTest

  # ---------------------------------------------------------------------------
  # Supervisor
  # ---------------------------------------------------------------------------

  @doc """
  Starts the PhoenixTestJsdom supervision tree. Call from test_helper.exs.

  Options:
    - `:setup_files` — list of paths to CJS modules invoked on every JSDom window (like vitest setupFiles)
    - `:cwd` — working directory for the Node.js process (enables resolving user-installed npm packages)

  Options can also be set via `config :phoenix_test_jsdom, key: value` in config/test.exs.
  """
  defdelegate start_link(opts \\ []), to: PhoenixTestJsdom.Supervisor
  defdelegate child_spec(opts), to: PhoenixTestJsdom.Supervisor

  @doc "Same as `start_link/1`; convenient alias used in sample `test_helper.exs` files."
  def start(opts \\ []), do: start_link(opts)

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  @doc """
  Mounts a LiveViewTest view (or `{:ok, view, html}` tuple) into a JSDom
  instance and returns the view.

  The pass-through tuple form is convenient when chaining directly after `live/2`:

      {:ok, view, html} = live(conn, "/react-counter") |> PhoenixTestJsdom.mount()
  """
  def mount({:ok, %LiveViewTest.View{} = view, html}) do
    mounted = do_mount_view(view, nil)
    {:ok, mounted, html}
  end

  def mount({:error, _} = err), do: err

  def mount(%LiveViewTest.View{} = view) do
    do_mount_view(view, nil)
  end

  @doc """
  Renders an isolated LiveComponent into a JSDom instance and returns a
  synthetic view.

  Requires `:endpoint` in `opts` to derive the base URL for script resolution.

      view = PhoenixTestJsdom.mount(MyComponent, %{id: "c"}, endpoint: MyEndpoint)
  """
  def mount(component, assigns \\ %{}, opts \\ []) when is_atom(component) do
    endpoint =
      opts[:endpoint] ||
        raise ArgumentError,
              "PhoenixTestJsdom.mount/3 for a LiveComponent requires :endpoint option"

    html = LiveViewTest.render_component(component, assigns)
    synthetic_view = %LiveViewTest.View{pid: self(), id: make_ref() |> inspect(), endpoint: endpoint}
    do_mount_view(synthetic_view, html)
  end

  defp do_mount_view(%LiveViewTest.View{proxy: nil} = view, html) do
    id = generate_id()
    url = base_url(view.endpoint) <> "/"
    :ok = Jsdom.mount_html(id, wrap_document(html), url)
    ViewRegistry.put(registry_key(view), id)
    view
  end

  defp do_mount_view(%LiveViewTest.View{} = view, _html) do
    # The proxy stores the URL with the default test conn host (www.example.com),
    # so we rebase the path onto the actual endpoint base URL.
    {:ok, proxy_url} = GenServer.call(elem(view.proxy, 2), :url)
    %{path: path, query: query} = URI.parse(proxy_url)
    url = base_url(view.endpoint) <> path <> if(query, do: "?#{query}", else: "")
    id = generate_id()
    :ok = Jsdom.visit(id, url)
    ViewRegistry.put(registry_key(view), id)
    view
  end

  # ---------------------------------------------------------------------------
  # Inspect (read from JSDom)
  # ---------------------------------------------------------------------------

  @doc """
  Returns the current HTML for the view.

  When the view has a JSDom instance (mounted via `mount/1`), returns the
  JSDom HTML — reflecting client-side mutations like React hook renders.

  Falls back to `Phoenix.LiveViewTest.render/1` for views not mounted in JSDom,
  so importing `render/1` from this module works for both JSDom and plain LV
  tests without needing to distinguish them at the call site.
  """
  def render(%LiveViewTest.View{} = view) do
    case ViewRegistry.fetch(view) do
      {:ok, id} ->
        {:ok, html} = Jsdom.get_html(id)
        html

      :error ->
        LiveViewTest.render(view)
    end
  end

  @doc "Returns the page title from JSDom, or nil."
  def page_title(%LiveViewTest.View{} = view) do
    id = ViewRegistry.fetch!(view)
    case Jsdom.get_title(id) do
      {:ok, ""} -> nil
      {:ok, title} -> title
      _ -> nil
    end
  end

  @doc "Returns the current path from JSDom."
  def current_path(%LiveViewTest.View{} = view) do
    id = ViewRegistry.fetch!(view)
    {:ok, path} = Jsdom.get_current_path(id)
    path
  end

  # ---------------------------------------------------------------------------
  # Lifecycle
  # ---------------------------------------------------------------------------

  @doc "Destroys the JSDom instance for the view and removes it from the registry."
  def unmount(%LiveViewTest.View{} = view) do
    ViewRegistry.delete(registry_key(view))
    view
  end

  # ---------------------------------------------------------------------------
  # render_* wrappers (return HTML, mirror LiveViewTest names)
  # ---------------------------------------------------------------------------

  @doc "Triggers a click event via LiveViewTest and re-mounts the resulting HTML into JSDom. Returns the HTML string."
  def render_click(view_or_element, value_or_opts \\ %{})

  def render_click(%LiveViewTest.View{} = view, opts) when is_list(opts) do
    element = resolve_element(view, opts)
    html = LiveViewTest.render_click(element)
    reseed!(view, html)
    html
  end

  def render_click(%LiveViewTest.View{} = view, value) do
    html = LiveViewTest.render_click(view, value)
    reseed!(view, html)
    html
  end

  def render_click(%LiveViewTest.Element{} = element, value) do
    LiveViewTest.render_click(element, value)
  end

  @doc "Triggers a submit event and re-mounts the HTML. Returns HTML."
  def render_submit(view_or_element, value \\ %{})

  def render_submit(%LiveViewTest.View{} = view, value) do
    html = LiveViewTest.render_submit(view, value)
    reseed!(view, html)
    html
  end

  def render_submit(%LiveViewTest.Element{} = element, value) do
    LiveViewTest.render_submit(element, value)
  end

  @doc "Triggers a change event and re-mounts the HTML. Returns HTML."
  def render_change(view_or_element, value \\ %{})

  def render_change(%LiveViewTest.View{} = view, value) do
    html = LiveViewTest.render_change(view, value)
    reseed!(view, html)
    html
  end

  def render_change(%LiveViewTest.Element{} = element, value) do
    LiveViewTest.render_change(element, value)
  end

  @doc "Triggers a keydown event and re-mounts the HTML into JSDom when called with a view. Returns HTML."
  def render_keydown(view_or_element, event, value \\ %{})
  def render_keydown(%LiveViewTest.View{} = view, event, value) do
    html = LiveViewTest.render_keydown(view, event, value)
    reseed!(view, html)
    html
  end
  def render_keydown(%LiveViewTest.Element{} = element, event, value) do
    LiveViewTest.render_keydown(element, event, value)
  end

  @doc "Triggers a keyup event and re-mounts the HTML into JSDom when called with a view. Returns HTML."
  def render_keyup(view_or_element, event, value \\ %{})
  def render_keyup(%LiveViewTest.View{} = view, event, value) do
    html = LiveViewTest.render_keyup(view, event, value)
    reseed!(view, html)
    html
  end
  def render_keyup(%LiveViewTest.Element{} = element, event, value) do
    LiveViewTest.render_keyup(element, event, value)
  end

  @doc "Triggers a blur event and re-mounts the HTML into JSDom when called with a view. Returns HTML."
  def render_blur(view_or_element, event, value \\ %{})
  def render_blur(%LiveViewTest.View{} = view, event, value) do
    html = LiveViewTest.render_blur(view, event, value)
    reseed!(view, html)
    html
  end
  def render_blur(%LiveViewTest.Element{} = element, event, value) do
    LiveViewTest.render_blur(element, event, value)
  end

  @doc "Triggers a focus event and re-mounts the HTML into JSDom when called with a view. Returns HTML."
  def render_focus(view_or_element, event, value \\ %{})
  def render_focus(%LiveViewTest.View{} = view, event, value) do
    html = LiveViewTest.render_focus(view, event, value)
    reseed!(view, html)
    html
  end
  def render_focus(%LiveViewTest.Element{} = element, event, value) do
    LiveViewTest.render_focus(element, event, value)
  end

  @doc "Triggers a hook push event and re-mounts the HTML into JSDom when called with a view. Returns HTML."
  def render_hook(view_or_element, event, value \\ %{})
  def render_hook(%LiveViewTest.View{} = view, event, value) do
    html = LiveViewTest.render_hook(view, event, value)
    reseed!(view, html)
    html
  end
  def render_hook(%LiveViewTest.Element{} = element, event, value) do
    LiveViewTest.render_hook(element, event, value)
  end

  @doc "Patches to a new path and re-mounts the HTML. Returns HTML."
  def render_patch(%LiveViewTest.View{} = view, path) do
    html = LiveViewTest.render_patch(view, path)
    reseed!(view, html)
    html
  end

  @doc "Waits for async operations and re-mounts the HTML. Returns HTML."
  def render_async(%LiveViewTest.View{} = view, timeout \\ 200) do
    html = LiveViewTest.render_async(view, timeout)
    reseed!(view, html)
    html
  end

  @doc "Advances an upload and re-mounts the HTML. Returns HTML."
  def render_upload(%LiveViewTest.Upload{} = upload, entry_name, percent \\ 100) do
    view = upload.view
    html = LiveViewTest.render_upload(upload, entry_name, percent)
    reseed!(view, html)
    html
  end

  @doc "Renders a LiveComponent to HTML, mounts it in JSDom, and returns a synthetic view."
  def render_component(component, assigns \\ %{}, opts \\ []) when is_atom(component) do
    mount(component, assigns, opts)
  end

  # ---------------------------------------------------------------------------
  # Pipable interaction functions (return view)
  # ---------------------------------------------------------------------------

  @doc """
  Clicks a button in JSDom and returns the view.

  This dispatches the click directly in the JSDom instance, so React-rendered
  buttons and other client-side elements are found and clicked. Any LiveView
  `pushEvent` fired by the click is handled by the LV client running inside JSDom.

  Options:
    - `:selector` — CSS selector restricting where to look (e.g. `"button"`)
    - `:within` — scope selector

  The text argument filters by button label.
  """
  def click(%LiveViewTest.View{} = view, text, opts \\ []) do
    id = ViewRegistry.fetch!(view)
    selector = opts[:selector]
    within = opts[:within]
    :ok = Jsdom.click_button(id, selector, text, within)
    view
  end

  @doc """
  Clicks a link in JSDom and returns the view.

  Options: `:selector`, `:within`.
  """
  def click_link(%LiveViewTest.View{} = view, text, opts \\ []) do
    id = ViewRegistry.fetch!(view)
    selector = opts[:selector] || "a"
    within = opts[:within]
    :ok = Jsdom.click_link(id, selector, text, within)
    view
  end

  @doc """
  Fills in an input in JSDom and returns the view.

  Options: `:selector`, `:within`. Use `:with` for the value.

      PhoenixTestJsdom.fill_in(view, "Email", with: "hello@example.com")
  """
  def fill_in(%LiveViewTest.View{} = view, label, opts) do
    id = ViewRegistry.fetch!(view)
    value = Keyword.fetch!(opts, :with) |> to_string()
    selector = opts[:selector]
    within = opts[:within]
    :ok = Jsdom.fill_in(id, selector, label, value, within)
    view
  end

  @doc "Submits a form in JSDom and returns the view. Options: `:selector`, `:within`."
  def submit(%LiveViewTest.View{} = view, opts \\ []) do
    id = ViewRegistry.fetch!(view)
    selector = opts[:selector] || "form"
    within = opts[:within]
    :ok = Jsdom.submit_form(id, selector, within)
    view
  end

  @doc "Selects an option in JSDom and returns the view. Use `:from` for the label."
  def select(%LiveViewTest.View{} = view, option, opts) do
    id = ViewRegistry.fetch!(view)
    label = Keyword.fetch!(opts, :from)
    selector = opts[:selector]
    within = opts[:within]
    :ok = Jsdom.select_option(id, selector, label, option, within)
    view
  end

  @doc "Checks a checkbox in JSDom and returns the view."
  def check(%LiveViewTest.View{} = view, label, opts \\ []) do
    id = ViewRegistry.fetch!(view)
    :ok = Jsdom.check(id, opts[:selector], label, opts[:within])
    view
  end

  @doc "Unchecks a checkbox in JSDom and returns the view."
  def uncheck(%LiveViewTest.View{} = view, label, opts \\ []) do
    id = ViewRegistry.fetch!(view)
    :ok = Jsdom.uncheck(id, opts[:selector], label, opts[:within])
    view
  end

  @doc "Chooses a radio button in JSDom and returns the view."
  def choose(%LiveViewTest.View{} = view, label, opts \\ []) do
    id = ViewRegistry.fetch!(view)
    :ok = Jsdom.choose(id, opts[:selector], label, opts[:within])
    view
  end

  @doc "Waits for a CSS selector to appear in JSDom and returns the view or session."
  def wait_for(view_or_session, selector, timeout \\ 5000)

  def wait_for(%LiveViewTest.View{} = view, selector, timeout) do
    id = ViewRegistry.fetch!(view)
    :ok = Jsdom.wait_for_selector(id, selector, timeout)
    view
  end

  def wait_for(%PhoenixTestJsdom.Session{} = session, selector, timeout) do
    :ok = Jsdom.wait_for_selector(session.instance_id, selector, timeout)
    session
  end

  @doc """
  Types text into the focused element (or the element matching `selector:` if given).

  Dispatches keydown/input/keyup events per character, mimicking user keyboard input.
  Use `\\n` to insert a newline / press Enter.

  Call `click/3` first to ensure an element is focused, or pass `selector:` directly.

  Returns the view or session for piping.
  """
  def type(view_or_session, text, opts \\ [])

  def type(%LiveViewTest.View{} = view, text, opts) when is_binary(text) do
    id = ViewRegistry.fetch!(view)
    :ok = Jsdom.type_text(id, text, opts[:selector])
    view
  end

  def type(%PhoenixTestJsdom.Session{} = session, text, opts) when is_binary(text) do
    :ok = Jsdom.type_text(session.instance_id, text, opts[:selector])
    session
  end

  @doc "Evaluates JavaScript in the JSDom window and returns `{:ok, string_result}` or `{:error, msg}`."
  def exec_js(%LiveViewTest.View{} = view, code) do
    id = ViewRegistry.fetch!(view)
    Jsdom.exec_js(id, code)
  end

  def exec_js(%PhoenixTestJsdom.Session{} = session, code) do
    Jsdom.exec_js(session.instance_id, code)
  end

  @doc "Patches the view to a new path (server + JSDom) and returns the view."
  def patch(%LiveViewTest.View{} = view, path) do
    render_patch(view, path)
    view
  end

  @doc "Waits for async server operations and re-mounts HTML in JSDom. Returns view."
  def async(%LiveViewTest.View{} = view, timeout \\ 200) do
    render_async(view, timeout)
    view
  end

  @doc "Advances an upload and returns the view."
  def upload(upload, entry_name, percent \\ 100) do
    render_upload(upload, entry_name, percent)
    upload.view
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp base_url(endpoint) do
    %{scheme: scheme, host: host, port: port} = endpoint.struct_url()
    "#{scheme}://#{host}:#{port}"
  end

  defp wrap_document(html) do
    "<!DOCTYPE html><html><head></head><body>#{html}</body></html>"
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end

  defp registry_key(%LiveViewTest.View{pid: pid, id: id}), do: {pid, id}

  defp reseed!(%LiveViewTest.View{} = view, html) do
    id = ViewRegistry.fetch!(view)
    url = base_url(view.endpoint) <> "/"
    :ok = Jsdom.patch_html(id, html, url)
  end

  defp resolve_element(%LiveViewTest.View{} = view, opts) do
    selector = opts[:selector] || raise ArgumentError, "expected :selector option"
    text = opts[:text]
    if text, do: LiveViewTest.element(view, selector, text), else: LiveViewTest.element(view, selector)
  end

end
