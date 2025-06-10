import Config

config :ash, :validate_domain_resource_inclusion?, false
config :ash, :validate_domain_config_inclusion?, false
config :logger, level: :info

config :ash_json_api, :show_public_calculations_when_loaded?, false
config :ash_json_api, :authorize_update_destroy_with_error?, true

if Mix.env() == :dev do
  config :git_ops,
    mix_project: AshJsonApi.MixProject,
    github_handle_lookup?: true,
    changelog_file: "CHANGELOG.md",
    repository_url: "https://github.com/ash-project/ash_json_api",
    # Instructs the tool to manage your mix version in your `mix.exs` file
    # See below for more information
    manage_mix_version?: true,
    # Instructs the tool to manage the version in your README.md
    # Pass in `true` to use `"README.md"` or a string to customize
    manage_readme_version: "documentation/tutorials/getting-started-with-ash-json-api.md",
    version_tag_prefix: "v"
end
