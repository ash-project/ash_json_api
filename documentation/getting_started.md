## Getting Started

The easiest set up involves using Phoenix. It should be roughly the same to set up an application using only Plug.

### Configure your resources and API

See `AshJsonApi.Api` and `AshJsonApi.Resource` for information on configuring your apis and resources.

### Accept json_api content type

Add the following to your `config/config.exs`

```elixir
# config/config.exs
config :mime, :types, %{
  "application/vnd.api+json" => ["json"]
}
```

This configuration is required to support working with the JSON:API custom mime type.

### Add the routes from your API module(s)

In your router, use `AshJsonApi.forward/2`.

For example:

```elixir
scope "/json_api" do
  pipe_through(:api)

  AshJsonApi.forward("/helpdesk", Helpdesk.Helpdesk.Api)
end
```

### Run your API

From here on out its the standard phoenix behavior. Start your application with `mix phx.server` and your API should be ready to try out
