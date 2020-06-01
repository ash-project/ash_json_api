defmodule AshJsonApi.MixProject do
  use Mix.Project

  @description """
  A rigorous JSON API front end for the `Ash` resource framework
  """

  @version "0.1.2"

  def project do
    [
      app: :ash_json_api,
      version: @version,
      elixir: "~> 1.9",
      description: @description,
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      source_url: "https://github.com/ash-project/ash_json_api",
      homepage_url: "https://github.com/ash-project/ash_json_api"
    ]
  end

  defp docs() do
    # The main page in the docs
    [main: "readme", extras: ["README.md"]]
  end

  defp package do
    [
      name: :ash_json_api,
      licenses: ["MIT"],
      links: %{
        GitHub: "https://github.com/ash-project/ash_json_api"
      }
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
      {:ash, "~> 0.1.2"},
      {:plug, "~> 1.8"},
      {:jason, "~> 1.1"},
      {:json_xema, "~> 0.4.0"},
      {:git_ops, "~> 2.0.0", only: :dev},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end
end
