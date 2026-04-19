defmodule PhoenixTestJsdom.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/tzeyiing/phoenix_test_jsdom"

  def project do
    [
      app: :phoenix_test_jsdom,
      version: @version,
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      docs: docs(),
      name: "PhoenixTestJsdom",
      description: "A PhoenixTest driver using JSDom for lightweight headless browser testing",
      package: package(),
      source_url: @source_url
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp aliases do
    [
      test: ["cmd npm run bundle --prefix priv", "test"]
    ]
  end

  defp deps do
    [
      {:phoenix_test, "~> 0.4"},
      {:jason, "~> 1.4"},
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 1.0"},
      {:bandit, "~> 1.0", only: :test},
      {:ex_doc, "~> 0.35", only: :dev, runtime: false},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
    ]
  end

  defp docs do
    [
      main: "PhoenixTestJsdom",
      source_ref: "v#{@version}",
      extras: [
        "README.md",
        "lib/phoenix_test_jsdom/usage.md": [title: "In-Depth Usage Guide"]
      ],
      groups_for_extras: [
        Guides: ~r"^lib/phoenix_test_jsdom/.*\\.md$"
      ]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv/dist/server.bundle.js mix.exs README.md LICENSE)
    ]
  end
end
