defmodule PhoenixTestJsdom.Jsdom do
  @moduledoc false

  alias PhoenixTestJsdom.NodeWorker

  def ping, do: NodeWorker.call("ping")

  def visit(id, url), do: call_ok("visit", [id, url])
  def mount_html(id, html, url), do: call_ok("mountHtml", [id, html, url])
  def patch_html(id, html, url), do: call_ok("patchHtml", [id, html, url])
  def destroy(id), do: call_ok_string("destroy", [id])

  def get_html(id), do: call_field("getHtml", [id])
  def get_title(id), do: call_field("getTitle", [id])
  def get_current_path(id), do: call_field("getCurrentPath", [id])

  def click_link(id, selector, text, within),
    do: call_ok("clickLink", [id, selector, text, within])

  def click_button(id, selector, text, within),
    do: call_ok("clickButton", [id, selector, text, within])

  def fill_in(id, selector, label, value, within),
    do: call_ok("fillIn", [id, selector, label, value, within])

  def select_option(id, selector, label, option, within),
    do: call_ok("selectOption", [id, selector, label, option, within])

  def check(id, selector, label, within),
    do: call_ok("check", [id, selector, label, within])

  def uncheck(id, selector, label, within),
    do: call_ok("uncheck", [id, selector, label, within])

  def choose(id, selector, label, within),
    do: call_ok("choose", [id, selector, label, within])

  def submit_form(id, form_selector, within),
    do: call_ok("submitForm", [id, form_selector, within])

  def wait_for_selector(id, selector, timeout \\ 5000),
    do: call_ok("waitForSelector", [id, selector, timeout])

  def fire_event(id, selector, text_filter, event_name, properties),
    do: call_ok("fireEvent", [id, selector, text_filter, event_name, properties])

  def type_text(id, text, selector \\ nil),
    do: call_ok("typeText", [id, text, selector])

  def exec_js(id, code), do: call_field("execJs", [id, code])

  defp call_ok(func, args) do
    case NodeWorker.call(func, args) do
      {:ok, %{"ok" => _}} -> :ok
      {:ok, %{"error" => msg}} -> {:error, msg}
      {:error, msg} -> {:error, msg}
      other -> other
    end
  end

  defp call_ok_string(func, args) do
    case NodeWorker.call(func, args) do
      {:ok, "ok"} -> :ok
      {:error, msg} -> {:error, msg}
      other -> other
    end
  end

  defp call_field(func, args) do
    case NodeWorker.call(func, args) do
      {:ok, %{"ok" => value}} -> {:ok, value}
      {:ok, %{"error" => msg}} -> {:error, msg}
      {:error, msg} -> {:error, msg}
      other -> other
    end
  end
end
