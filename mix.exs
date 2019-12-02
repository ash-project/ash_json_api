defmodule AshJsonApi.MixProject do
  use Mix.Project

  def project do
    [
      app: :ash_json_api,
      version: "0.1.0",
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {AshJsonApi.Application, []}
    ]
  end

  defp elixirc_paths(:test) do
    ["test/support/", "lib/"]
  end

  defp elixirc_paths(_env) do
    ["lib/"]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ash, path: "../ash"},
      {:plug, "~> 1.8"},
      {:jason, "~> 1.1"},
      {:json_xema, "~> 0.3"}
    ]
  end
end
