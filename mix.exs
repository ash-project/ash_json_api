defmodule AshJsonApi.MixProject do
  use Mix.Project

  @description """
  The JSON:API extension for the Ash Framework.
  """

  @version "1.4.31"

  def project do
    [
      app: :ash_json_api,
      version: @version,
      elixir: "~> 1.11",
      description: @description,
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      consolidate_protocols: Mix.env() == :prod,
      dialyzer: [
        plt_add_apps: [:ex_unit, :open_api_spex, :mix]
      ],
      deps: deps(),
      docs: &docs/0,
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
      CHANGELOG* documentation usage-rules.md),
      links: %{
        GitHub: "https://github.com/ash-project/ash_json_api"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: [
        {"README.md", title: "Home"},
        "documentation/tutorials/getting-started-with-ash-json-api.md",
        "documentation/topics/what-is-ash-json-api.md",
        "documentation/topics/non-spec-query-parameters.md",
        "documentation/topics/open-api.md",
        "documentation/topics/relationships.md",
        "documentation/topics/links.md",
        "documentation/topics/upgrade.md",
        "documentation/topics/authorize-with-json-api.md",
        "documentation/topics/authenticate-with-json-api.md",
        {"documentation/dsls/DSL-AshJsonApi.Resource.md",
         search_data: Spark.Docs.search_data_for(AshJsonApi.Resource)},
        {"documentation/dsls/DSL-AshJsonApi.Domain.md",
         search_data: Spark.Docs.search_data_for(AshJsonApi.Domain)},
        "CHANGELOG.md"
      ],
      groups_for_extras: [
        Tutorials: ~r'documentation/tutorials',
        "How To": ~r'documentation/how_to',
        Topics: ~r'documentation/topics',
        DSLs: ~r'documentation/dsls',
        "About AshJsonApi": [
          "CHANGELOG.md"
        ]
      ],
      before_closing_head_tag: fn type ->
        if type == :html do
          """
          <script>
            if (location.hostname === "hexdocs.pm") {
              var script = document.createElement("script");
              script.src = "https://plausible.io/js/script.js";
              script.setAttribute("defer", "defer")
              script.setAttribute("data-domain", "ashhexdocs")
              document.head.appendChild(script);
            }
          </script>
          """
        end
      end,
      groups_for_modules: [
        AshJsonApi: [
          AshJsonApi,
          AshJsonApi.Router,
          AshJsonApi.Resource,
          AshJsonApi.Domain
        ],
        Utilities: [
          AshJsonApi.OpenApi,
          AshJsonApi.Test
        ],
        Introspection: [
          AshJsonApi.Resource.Info,
          AshJsonApi.Domain.Info,
          AshJsonApi.Resource.Route
        ],
        Errors: [
          ~r/AshJsonApi.Error.*/,
          AshJsonApi.ToJsonApiError
        ],
        Internals: ~r/.*/
      ],
      logo: "logos/small-logo.png"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
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
      {:ash, ash_version("~> 3.0 and >= 3.4.69")},
      {:spark, "~> 2.2 and >= 2.2.10"},
      {:igniter, "~> 0.3 and >= 0.3.58", optional: true},
      {:plug, "~> 1.11"},
      {:jason, "~> 1.1"},
      {:phoenix, "~> 1.6"},
      {:json_xema, "~> 0.4"},
      {:multipart, "~> 0.4.0", only: [:dev, :test]},
      {:open_api_spex, "~> 3.16", optional: true},
      {:git_ops, "~> 2.4", only: [:dev, :test]},
      {:ex_doc, "~> 0.37-rc", only: [:dev, :test]},
      {:ex_check, "~> 0.12", only: [:dev, :test]},
      {:credo, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:dialyxir, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:sobelow, ">= 0.0.0", only: [:dev, :test], runtime: false},
      {:mix_audit, ">= 0.0.0", only: [:dev, :test], runtime: false}
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
      docs: [
        "spark.cheat_sheets",
        "docs",
        "spark.replace_doc_links"
      ],
      "spark.formatter": "spark.formatter --extensions AshJsonApi.Resource,AshJsonApi.Domain",
      "spark.cheat_sheets":
        "spark.cheat_sheets --extensions AshJsonApi.Resource,AshJsonApi.Domain"
    ]
  end
end
