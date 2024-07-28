# Getting started with AshJsonApi

## Installing AshJsonApi

<!-- tabs-open -->

### Using Igniter (recommended)

```sh
mix igniter.install ash_json_api
```

After running the command above, you might encounter an error:

```
** (UndefinedFunctionError) function Igniter.Libs.Phoenix.web_module_name/1 is undefined (module Igniter.Libs.Phoenix is not available)
```

This can be fixed by running:

```
mix deps.compile
```

### Manually

This manual setup branches off from the [Getting Started with Ash](https://hexdocs.pm/ash/get-started.html) guide.
If you aren't starting from there, replace the application name, `Helpdesk`, with your application name,
and replace the `Ash.Domain` name, `Helpdesk.Support` with a domain or domains from your own application.

#### Add the ash_json_api dependency

In your mix.exs, add the Ash JSON API dependency:

```elixir
  defp deps do
    [
      # .. other dependencies
      {:ash_json_api, "~> 1.0"},
    ]
  end
```

#### Accept json_api content type

Add the following to your `config/config.exs`.

```elixir
# config/config.exs
config :mime,
  extensions: %{"json" => "application/vnd.api+json"},
  types: %{"application/vnd.api+json" => ["json"]}
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

#### Create a router

Create a separate Router Module to work with your Domains. It will generate the routes for
your Resources and provide the functions you would usually have in a Controller.

We will later forward requests from your Applications primary (Phoenix) Router to you Ash JSON API Router.

```elixir
defmodule HelpdeskWeb.JsonApiRouter do
  use AshJsonApi.Router,
    # The api modules you want to serve
    domains: [Module.concat(["Helpdesk.Support"])],
    # optionally an open_api route
    open_api: "/open_api",
    prefix: "/api/json"
end
```

> ### Whats up with `Module.concat/1`? {: .info}
>
> This `Module.concat/1` prevents a [compile-time dependency](https://dashbit.co/blog/speeding-up-re-compilation-of-elixir-projects) from this router module to the domain modules. It is an implementation detail of how `forward/2` works that you end up with a compile-time dependency on the schema, but there is no need for this dependency, and that dependency can have _drastic_ impacts on your compile times in certain scenarios.

Additionally, your Resource requires a type, a base route and a set of allowed HTTP methods and what action they will trigger.

#### Add the routes from your domain module(s)

To make your Resources accessible to the outside world, forward requests from your Phoenix router to the router you created for your domains.

For example:

```elixir
scope "/api/json" do
  pipe_through(:api)

  forward "/helpdesk", HelpdeskWeb.JsonApiRouter
end
```

<!-- tabs-close -->

## Configure your Resources and Domain and expose actions

These examples are based off of the [Getting Started with Ash](https://hexdocs.pm/ash/get-started.html) guide.

### Add the AshJsonApi extension to your domain and resource

<!-- tabs-open -->

### Using Igniter (recommended)

To set up an existing resource of your own with `AshJsonApi`, run:

```sh
mix ash.patch.extend Your.Resource.Name json_api
```

### Manually

Add to your domain:

```elixir
defmodule Helpdesk.Support do
  use Ash.Domain, extensions: [AshJsonApi.Domain]
  ...
```

And to your resource:

```elixir
defmodule Helpdesk.Support.Ticket do
  use Ash.Resource, extensions: [AshJsonApi.Resource]
  # ...
  json_api do
    type "ticket"
  end
end
```

<!-- tabs-close -->

## Define Routes

Routes can be defined on the resource or the domain. If you define them on the domain (which is our default recommendation), the resource in question must still use the `AshJsonApi.Resource` extension, and define its own type.

### Defining routes on the domain

```elixir
defmodule Helpdesk.Support do
  use Ash.Domain, extensions: [AshJsonApi.Domain]

  json_api do
    routes do
      # in the domain `base_route` acts like a scope
      base_route "/tickets", Helpdesk.Support.Ticket do
        get :read
        index :read
        post :create
      end
    end
  end
end
```

And then add the extension and type to the resource:

```elixir
defmodule Helpdesk.Support.Ticket do
  use Ash.Resource, extensions: [AshJsonApi.Resource]
  # ...
  json_api do
    type "ticket"
  end
end
```

### Defining routes on the resource

Here we show an example of defining routes on the resource.

```elixir
defmodule Helpdesk.Support.Ticket do
  use Ash.Resource, extensions: [AshJsonApi.Resource]
  # ...
  json_api do
    type "ticket"

    routes do
      # on the resource, the `base` applies to all routes
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

## Run your API

From here on out its the standard Phoenix behavior. Start your application with `mix phx.server`
and your API should be ready to try out. Should you be wondering what routes are available, you can
print all available routes for each Resource:

```elixir
Helpdesk.Support.Ticket
|> AshJsonApi.Resource.Info.routes(Helpdesk.Support)
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
