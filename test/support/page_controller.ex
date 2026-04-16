defmodule PhoenixTestJsdom.PageController do
  use Phoenix.Controller, formats: [:html]

  plug(:put_layout, false)

  def index(conn, _params) do
    html(conn, """
    <html>
    <head><title>Test Page</title></head>
    <body>
      <h1>Welcome</h1>
      <a href="/about">About</a>
    </body>
    </html>
    """)
  end

  def about(conn, _params) do
    html(conn, """
    <html>
    <head><title>About</title></head>
    <body>
      <h1>About Us</h1>
      <a href="/">Home</a>
    </body>
    </html>
    """)
  end

  def form(conn, _params) do
    html(conn, """
    <html>
    <head><title>Form</title></head>
    <body>
      <h1>Contact Form</h1>
      <form action="/submit" method="post">
        <input type="hidden" name="_csrf_token" value="#{Plug.CSRFProtection.get_csrf_token()}" />
        <label for="name">Name</label>
        <input id="name" name="name" type="text" />

        <label for="email">Email</label>
        <input id="email" name="email" type="text" />

        <label for="role">Role</label>
        <select id="role" name="role">
          <option value="user">User</option>
          <option value="admin">Admin</option>
        </select>

        <label for="agree">I agree</label>
        <input id="agree" name="agree" type="checkbox" value="yes" />

        <label for="color-red">Red</label>
        <input id="color-red" name="color" type="radio" value="red" />
        <label for="color-blue">Blue</label>
        <input id="color-blue" name="color" type="radio" value="blue" />

        <button type="submit">Submit</button>
      </form>
    </body>
    </html>
    """)
  end

  def react_counter(conn, _params) do
    html(conn, """
    <html>
    <head><title>React Counter</title></head>
    <body>
      <div id="app"></div>
      <script src="/assets/react/react.development.js"></script>
      <script src="/assets/react-dom/react-dom.development.js"></script>
      <script>
        function Counter() {
          var ref = React.useState(0);
          var count = ref[0], setCount = ref[1];
          return React.createElement('div', null,
            React.createElement('p', {id: 'count-display'}, 'Count: ' + count),
              React.createElement('p', null, 'hello from react static'),
            React.createElement('button', {id: 'inc-btn', onClick: function() { setCount(count + 1); }}, 'Increment'),
            React.createElement('button', {id: 'dec-btn', onClick: function() { setCount(count - 1); }}, 'Decrement')
          );
        }
        var container = document.getElementById('app');
        if (typeof ReactDOM.createRoot === 'function') {
          ReactDOM.createRoot(container).render(React.createElement(Counter));
        } else {
          ReactDOM.render(React.createElement(Counter), container);
        }
      </script>
    </body>
    </html>
    """)
  end

  def submit(conn, params) do
    name = params["name"] || "unknown"

    html(conn, """
    <html>
    <head><title>Submitted</title></head>
    <body>
      <h1>Thanks, #{name}!</h1>
    </body>
    </html>
    """)
  end
end
