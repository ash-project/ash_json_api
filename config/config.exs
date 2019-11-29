use Mix.Config

if Mix.env() == :test do
  config :ash,
    resources: [
      AshJsonApi.Test.Resources.Post
    ]
end
