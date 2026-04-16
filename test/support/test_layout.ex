defmodule PhoenixTestJsdom.TestLayout do
  use Phoenix.Component

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html>
    <head>
      <meta name="csrf-token" content={Plug.CSRFProtection.get_csrf_token()} />
      <title>{assigns[:page_title] || "Test"}</title>
    </head>
    <body>
      {@inner_content}
      <script src="/assets/phoenix/phoenix.js"></script>
      <script src="/assets/lv/phoenix_live_view.js"></script>
      <script>
        var csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
        var liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, {params: {_csrf_token: csrfToken}, hooks: window.Hooks || {}});
        liveSocket.connect();
      </script>
    </body>
    </html>
    """
  end
end
