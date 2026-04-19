defmodule PhoenixTestJsdom.MixProject do
  use Mix.Project

  @version "0.1.2"
  @source_url "https://github.com/ziinc/phoenix_test_jsdom"

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
      description: "A Phoenix LiveView testing library that uses jsdom for full JavaScript integration testing",
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
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false}
    ]
  end

  defp docs do
    [
      main: "PhoenixTestJsdom",
      source_ref: "v#{@version}",
      main: "readme",
      extras: ["README.md"]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "https://github.com/Ziinc/phoenix_test_jsdom/releases"
      },
      files: ~w(lib priv/dist/server.bundle.js mix.exs README.md LICENSE)
    ]
  end
end
