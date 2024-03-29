# Getting started with JSON:API

The easiest set up involves using Phoenix, but it should be roughly the same to set up an
application using only Plug. We are showing examples using Phoenix Routers.

The resulting JSON APIs follow the specifications from https://jsonapi.org/.

To add a JSON API, we need to do the following things:

1. Add the `:ash_json_api` package to your dependencies.
2. Add the JSON API extension to your `Ash.Resource` and `Ash.Domain` modules.
3. Tell Ash which Resource actions expose over the API.
4. Add a custom media type as specified by https://jsonapi.org/.
5. Create a router module
6. Make your router available in your applications main router.

## Add the ash_json_api dependency

In your mix.exs, add the Ash JSON API dependency:

```elixir
  defp deps do
    [
      # .. other dependencies
      {:ash_json_api, "~> 0.34.2"},
    ]
  end
```

## Configure your Resources and Domain and expose actions

Both your Resource and domain need to use the extension for the JSON API.

```elixir
defmodule Helpdesk.Support do
  use Ash.Domain, extensions: [AshJsonApi.Domain]
  ...
```

Additionally, your Resource requires a type, a base route and a set of allowed HTTP methods
and what action they will trigger.

```elixir
defmodule Helpdesk.Support.Ticket do
  use Ash.Resource, extensions: [AshJsonApi.Resource]
  # ...
  json_api do
    type "ticket"

    routes do
      base "/tickets"

      get :read
      index :read
      post :create
      # ...
    end
  end
end
```

Check out the [AshJsonApi.Resource documentation on
Hex](https://hexdocs.pm/ash_json_api/AshJsonApi.Resource.html) for more information.

## Accept json_api content type

Add the following to your `config/config.exs`.

```elixir
# config/config.exs
config :mime, :types, %{
  "application/vnd.api+json" => ["json"]
}

config :mime, :extensions, %{
  "json" => "application/vnd.api+json"
}
```

This configuration is required to support working with the JSON:API custom mime type.

After adding the configuration above, compiling the project might throw an error:

```
ERROR! the application :mime has a different value set for key :types during runtime compared to compile time.
```

This can happen if `:mime` was already compiled before the configuration was changed and can be
fixed by running

```
mix deps.compile mime --force
```

## Create a router

Create a separate Router Module to work with your Domains. It will generate the routes for
your Resources and provide the functions you would usually have in a Controller.

We will later forward requests from your Applications primary (Phoenix) Router to you Ash JSON API Router.

```elixir
defmodule HelpdeskWeb.Support.Router do
  use AshJsonApi.Router,
    # The api modules you want to serve
    domains: [Helpdesk.Support],
    # optionally a json_schema route
    json_schema: "/json_schema",
    # optionally an open_api route
    open_api: "/open_api"

end
```

## Add the routes from your domain module(s)

To make your Resources accessible to the outside world, forward requests from your Phoenix router to the router you created for your domains.

For example:

```elixir
scope "/api/json" do
  pipe_through(:api)

  forward "/helpdesk", HelpdeskWeb.Support.Router
end
```

## Run your API

From here on out its the standard Phoenix behavior. Start your application with `mix phx.server`
and your API should be ready to try out. Should you be wondering what routes are available, you can
print all available routes for each Resource:

```elixir
Helpdesk.Support.Ticket
|> AshJsonApi.Resource.Info.routes()
```

Make sure that all requests you make to the API use the `application/vnd.api+json` type in both the
`Accept` and `Content-Type` (where applicable) headers. The `Accept` header may be omitted.

Examples:

1. Create a ticket
   ```bash
   curl -X POST 'localhost:4000/api/json/helpdesk/tickets' \
   --header 'Accept: application/vnd.api+json' \
   --header 'Content-Type: application/vnd.api+json' \
   --data-raw '{
     "data": {
       "type": "ticket",
       "attributes": {
         "subject": "This ticket was created through the JSON API"
       }
     }
   }'
   ```
1. Get all tickets
   ```bash
   curl 'localhost:4000/api/json/helpdesk/tickets'
   ```
1. Get a specific ticket
   ```bash
   # Add the uuid of a Ticket you created earlier
   curl 'localhost:4000/api/json/helpdesk/tickets/<uuid>'
   ```

## Open API

If you want to expose your API via Swagger UI or Redoc, see [the open api documentation](/documentation/topics/open-api.md).
