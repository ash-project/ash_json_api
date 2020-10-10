defmodule AshJsonApi.MixProject do
  use Mix.Project

  @description """
  A rigorous JSON API front end for the `Ash` resource framework
  """

  @version "0.20.0"

  def project do
    [
      app: :ash_json_api,
      version: @version,
      elixir: "~> 1.9",
      description: @description,
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      docs: docs(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.github": :test
      ],
      dialyzer: [
        plt_add_apps: [:ex_unit]
      ],
      deps: deps(),
      docs: docs(),
      aliases: aliases(),
      package: package(),
      source_url: "https://github.com/ash-project/ash_json_api",
      homepage_url: "https://github.com/ash-project/ash_json_api"
    ]
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

  defp docs do
    [
      main: "AshJsonApi",
      source_ref: "v#{@version}",
      logo: "logos/small-logo.png",
      groups_for_modules: [
        entrypoint: [AshJsonApi],
        "resource dsl transformers": ~r/AshJsonApi.Resource.Transformers/,
        "resource dsl": ~r/AshJsonApi.Resource/,
        "api dsl transformers": ~r/AshJsonApi.Api.Transformers/,
        "api dsl": ~r/AshJsonApi.Api/,
        errors: ~r/AshJsonApi.Error/
      ]
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
      {:ash, ash_version("~> 1.16")},
      {:plug, "~> 1.8"},
      {:jason, "~> 1.1"},
      {:json_xema, "~> 0.4.0"},
      {:git_ops, "~> 2.0.1", only: :dev},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false},
      {:ex_check, "~> 0.12.0", only: :dev},
      {:credo, ">= 0.0.0", only: :dev, runtime: false},
      {:dialyxir, ">= 0.0.0", only: :dev, runtime: false},
      {:sobelow, ">= 0.0.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.13.0", only: [:dev, :test]}
    ]
  end

  defp ash_version(default_version) do
    case System.get_env("ASH_VERSION") do
      nil -> default_version
      "local" -> [path: "../ash"]
      "master" -> [git: "https://github.com/ash-project/ash.git"]
      version -> "~> #{version}"
    end
  end

  defp aliases do
    [
      sobelow: "sobelow --skip",
      credo: "credo --strict",
      "ash.formatter": "ash.formatter --extensions AshJsonApi.Resource,AshJsonApi.Api"
    ]
  end
end
