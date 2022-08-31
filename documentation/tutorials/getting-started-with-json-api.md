# Getting started with JSON:API

The easiest set up involves using Phoenix, but it should be roughly the same to set up an application using only Plug.

## Configure your resources and API

See the DSL documentation for information on configuring

## Create a router

```elixir
defmodule MyApp.MyApi.Router do
  # The registry must be explicitly provided here
  use AshJsonApi.Api.Router, api: Api, registry: Registry 
end
```

## Accept json_api content type

Add the following to your `config/config.exs`

```elixir
# config/config.exs
config :mime, :types, %{
  "application/vnd.api+json" => ["json"]
}
```

This configuration is required to support working with the JSON:API custom mime type.

## Add the routes from your API module(s)

Forward requests to the from your Phoenix router to the router you created for your Api.

For example:

```elixir
scope "/json_api" do
  pipe_through(:api)

  forward "/helpdesk", MyApp.MyApi.Router
end
```

## Run your API

From here on out its the standard phoenix behavior. Start your application with `mix phx.server` and your API should be ready to try out
