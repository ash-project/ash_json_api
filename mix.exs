defmodule AshJsonApi.MixProject do
  use Mix.Project

  @description """
  A JSON API front end for the `Ash` resource framework
  """

  @version "0.32.0"

  def project do
    [
      app: :ash_json_api,
      version: @version,
      elixir: "~> 1.11",
      description: @description,
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      consolidate_protocols: Mix.env() == :prod,
      docs: docs(),
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.github": :test
      ],
      dialyzer: [
        plt_add_apps: [:ex_unit, :open_api_spex]
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
      files: ~w(lib .formatter.exs mix.exs README* LICENSE*
      CHANGELOG* documentation),
      links: %{
        GitHub: "https://github.com/ash-project/ash_json_api"
      }
    ]
  end

  defp extras() do
    "documentation/**/*.md"
    |> Path.wildcard()
    |> Enum.map(fn path ->
      title =
        path
        |> Path.basename(".md")
        |> String.split(~r/[-_]/)
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")
        |> case do
          "F A Q" ->
            "FAQ"

          other ->
            other
        end

      {String.to_atom(path),
       [
         title: title
       ]}
    end)
  end

  defp groups_for_extras() do
    "documentation/*"
    |> Path.wildcard()
    |> Enum.map(fn folder ->
      name =
        folder
        |> Path.basename()
        |> String.split(~r/[-_]/)
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")

      {name, folder |> Path.join("**") |> Path.wildcard()}
    end)
  end

  defp docs do
    [
      main: "getting-started-with-json-api",
      source_ref: "v#{@version}",
      extras: extras(),
      groups_for_extras: groups_for_extras(),
      spark: [
        extensions: [
          %{
            module: AshJsonApi.Resource,
            name: "AshJsonApi Resource",
            target: "Ash.Resource",
            type: "JSON:API Resource"
          },
          %{
            module: AshJsonApi.Api,
            name: "AshJsonApi Api",
            target: "Ash.Api",
            type: "JSON:API Api"
          }
        ]
      ],
      groups_for_modules: [
        AshJsonApi: [
          AshJsonApi,
          AshJsonApi.Api.Router
        ],
        Introspection: [
          AshJsonApi.Resource.Info,
          AshJsonApi.Api.Info
        ],
        Internals: ~r/.*/
      ],
      logo: "logos/small-logo.png"
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
      {:ash, ash_version("~> 2.3 and >= 2.9.24")},
      {:plug, "~> 1.11"},
      {:jason, "~> 1.1"},
      {:json_xema, "~> 0.4.0"},
      {:open_api_spex, "~> 3.16", optional: true},
      {:git_ops, "~> 2.4", only: [:dev, :test]},
      {:ex_doc, "~> 0.23", only: [:dev, :test], runtime: false},
      {:ex_check, "~> 0.12.0", only: [:dev, :test]},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.13.0", only: [:dev, :test]}
    ]
  end

  defp ash_version(default_version) do
    case System.get_env("ASH_VERSION") do
      nil -> default_version
      "local" -> [path: "../ash"]
      "main" -> [git: "https://github.com/ash-project/ash.git"]
      version -> "~> #{version}"
    end
  end

  defp aliases do
    [
      sobelow: "sobelow --skip",
      credo: "credo --strict",
      docs: ["docs", "ash.replace_doc_links"],
      "spark.formatter": "spark.formatter --extensions AshJsonApi.Resource,AshJsonApi.Api"
    ]
  end
end
