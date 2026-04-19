# Usage Guide

A comprehensive usage guide for integrating PhoenixTestJsdom into your test suite.

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
<!-- link to example test file -->

### Triggering custom events

### Mounting React components
<!-- add in monaco editor link to file example -->

### Using to render web pages

### Adding shims/stubs with setup files

