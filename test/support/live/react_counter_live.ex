defmodule PhoenixTestJsdom.ReactCounterLive do
  use Phoenix.LiveView

  def mount(_params, _session, socket) do
    {:ok, assign(socket, count: 0)}
  end

  def render(assigns) do
    ~H"""
    <script src="/assets/react/react.development.js">
    </script>
    <script src="/assets/react-dom/react-dom.development.js">
    </script>
    <script>
      window.Hooks = window.Hooks || {};
      window.Hooks.ReactCounter = {
        mounted() {
          var hook = this;
          var setCountRef = {current: null};

          function Counter(props) {
            var ref = React.useState(props.initialCount);
            var count = ref[0];
            setCountRef.current = ref[1];
            return React.createElement('div', null,
              React.createElement('p', {id: 'count-display'}, 'Count: ' + count),
              React.createElement('p', null, 'hello from react liveview'),
              React.createElement('button', {id: 'inc-btn', onClick: function() { hook.pushEvent('inc', {}); }}, 'Increment'),
              React.createElement('button', {id: 'dec-btn', onClick: function() { hook.pushEvent('dec', {}); }}, 'Decrement')
            );
          }

          var counterElement = React.createElement(
            Counter,
            {initialCount: parseInt(this.el.dataset.count || '0', 10)}
          );
          if (typeof ReactDOM.createRoot === 'function') {
            ReactDOM.createRoot(this.el).render(counterElement);
          } else {
            ReactDOM.render(counterElement, this.el);
          }

          this.handleEvent("update_count", function(data) {
            if (setCountRef.current) setCountRef.current(data.count);
          });
        }
      };
    </script>
    <div id="react-root" phx-hook="ReactCounter" phx-update="ignore" data-count={@count}></div>
    """
  end

  def handle_event("inc", _params, socket) do
    socket = update(socket, :count, &(&1 + 1))
    {:noreply, push_event(socket, "update_count", %{count: socket.assigns.count})}
  end

  def handle_event("dec", _params, socket) do
    socket = update(socket, :count, &(&1 - 1))
    {:noreply, push_event(socket, "update_count", %{count: socket.assigns.count})}
  end
end
