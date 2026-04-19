defmodule PhoenixTestJsdom.Session do
  @moduledoc """
  The test session struct that implements `PhoenixTest.Driver`.

  Uses a real JSDom instance backed by Node.js. JSDom executes page JavaScript
  including the LiveView client, connects via WebSocket, and handles LiveView
  patches — acting as a lightweight headless browser.

      session = PhoenixTestJsdom.Session.new(MyApp.Endpoint)

      session
      |> visit("/counter")
      |> click_button("Increment")
      |> assert_has("h1", text: "Counter: 1")
  """

  alias PhoenixTestJsdom.Jsdom
  alias PhoenixTest.Html

  defstruct [:instance_id, :endpoint, :base_url, within: :none]

  def new(endpoint) do
    %__MODULE__{endpoint: endpoint, base_url: base_url(endpoint)}
  end

  defp base_url(endpoint) do
    %{scheme: scheme, host: host, port: port} = endpoint.struct_url()
    "#{scheme}://#{host}:#{port}"
  end

  @doc false
  def gen_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)

  defimpl PhoenixTest.Driver do
    alias PhoenixTestJsdom.{Jsdom, Session}
    alias PhoenixTest.{Assertions, Html}

    def visit(session, path) do
      id = Session.gen_id()
      url = session.base_url <> path
      :ok = Jsdom.visit(id, url)
      %{session | instance_id: id}
    end

    def render_html(session) do
      {:ok, html} = Jsdom.get_html(session.instance_id)
      parsed = Html.parse_document(html)

      case session.within do
        :none -> parsed
        selector -> Html.all(parsed, selector)
      end
    end

    def render_page_title(session) do
      case Jsdom.get_title(session.instance_id) do
        {:ok, ""} -> nil
        {:ok, title} -> title
        _ -> nil
      end
    end

    def current_path(session) do
      {:ok, path} = Jsdom.get_current_path(session.instance_id)
      path
    end

    def reload_page(session) do
      visit(session, current_path(session))
    end

    def click_link(session, text), do: click_link(session, "a", text)

    def click_link(session, selector, text) do
      :ok = Jsdom.click_link(session.instance_id, selector, text, within(session))
      session
    end

    def click_button(session, text), do: click_button(session, nil, text)

    def click_button(session, selector, text) do
      :ok = Jsdom.click_button(session.instance_id, selector, text, within(session))
      session
    end

    def fill_in(session, label, opts), do: fill_in(session, nil, label, opts)

    def fill_in(session, selector, label, opts) do
      {value, _opts} = Keyword.pop!(opts, :with)
      :ok = Jsdom.fill_in(session.instance_id, selector, label, to_string(value), within(session))
      session
    end

    def select(session, option, opts), do: select(session, nil, option, opts)

    def select(session, selector, option, opts) do
      {label, _opts} = Keyword.pop!(opts, :from)
      :ok = Jsdom.select_option(session.instance_id, selector, label, option, within(session))
      session
    end

    def check(session, label, opts), do: check(session, nil, label, opts)

    def check(session, selector, label, _opts) do
      :ok = Jsdom.check(session.instance_id, selector, label, within(session))
      session
    end

    def uncheck(session, label, opts), do: uncheck(session, nil, label, opts)

    def uncheck(session, selector, label, _opts) do
      :ok = Jsdom.uncheck(session.instance_id, selector, label, within(session))
      session
    end

    def choose(session, label, opts), do: choose(session, nil, label, opts)

    def choose(session, selector, label, _opts) do
      :ok = Jsdom.choose(session.instance_id, selector, label, within(session))
      session
    end

    def upload(_session, _label, _path, _opts),
      do: raise("upload not yet supported in JSDom driver")

    def upload(_session, _sel, _label, _path, _opts),
      do: raise("upload not yet supported in JSDom driver")

    def submit(session) do
      :ok = Jsdom.submit_form(session.instance_id, "form", within(session))
      session
    end

    def within(session, selector, fun) do
      session |> Map.put(:within, selector) |> fun.() |> Map.put(:within, :none)
    end

    def unwrap(session, fun) do
      fun.(session)
      session
    end

    def open_browser(session),
      do: open_browser(session, &PhoenixTest.OpenBrowser.open_with_system_cmd/1)

    def open_browser(session, open_fun) do
      {:ok, html} = Jsdom.get_html(session.instance_id)
      path = Path.join([System.tmp_dir!(), "phx-test#{System.unique_integer([:monotonic])}.html"])
      File.write!(path, html)
      open_fun.(path)
      session
    end

    defdelegate assert_has(session, selector), to: Assertions
    defdelegate assert_has(session, selector, opts), to: Assertions
    defdelegate refute_has(session, selector), to: Assertions
    defdelegate refute_has(session, selector, opts), to: Assertions
    defdelegate assert_path(session, path), to: Assertions
    defdelegate assert_path(session, path, opts), to: Assertions
    defdelegate refute_path(session, path), to: Assertions
    defdelegate refute_path(session, path, opts), to: Assertions

    defp within(%{within: :none}), do: nil
    defp within(%{within: selector}), do: selector
  end
end
