# Open API

## Use with Phoenix

To set up the Open API endpoints for your application, first include the `:open_api_spex` dependency:

```elixir
{:open_api_spex, "~> 3.16"},
```

Then in the module where you call `use AshJsonApi.Router` add the following option:

```elixir
use AshJsonApi.Router, domains: [...], open_api: "/open_api"
```

Finally, you can use utilities provided by `open_api_spex` to show UIs for your API. Be sure to put your `forward` call last, if you are putting your API at a sub-path.

```elixir
forward "/api/swaggerui",
  OpenApiSpex.Plug.SwaggerUI,
  path: "/api/open_api",
  title: "Myapp's JSON-API - Swagger UI",
  default_model_expand_depth: 4

forward "/api/redoc",
  Redoc.Plug.RedocUI,
  spec_url: "/api/open_api"

forward "/api", YourApp.YourApiRouter
```

Now you can go to `/api/swaggerui` and `/api/redoc`!

## Use with Plug

To set up the open API endpoints for your application, first include the `:open_api_spex` and `:redoc_ui_plug` dependency:

```elixir
{:open_api_spex, "~> 3.16"},
{:redoc_ui_plug, "~> 0.2.1"},
```

Then in the module where you call `use AshJsonApi.Router` add the following option:

```elixir
use AshJsonApi.Router, domains: [...], open_api: "/open_api"
```

Finally, you can use utilities provided by `open_api_spex` to show UIs for your API. Be sure to put your `forward` call last, if you are putting your API at a sub-path.

```elixir
forward "/api/swaggerui",
  to: OpenApiSpex.Plug.SwaggerUI,
  init_opts: [
    path: "/api/open_api",
    title: "Myapp's JSON-API - Swagger UI",
    default_model_expand_depth: 4
  ]

forward "/api/redoc",
  to: Redoc.Plug.RedocUI,
  init_opts: [
    spec_url: "/api/open_api"
  ]

forward "/api", YourApp.YourApiRouter
```

Now you can go to `/api/swaggerui` and `/api/redoc`!

## Customize values in the OpenAPI documentation

To override any value in the OpenApi documentation you can use the `:modify_open_api` options key:

```elixir
  use AshJsonApi.Router,
    domains: [...],
    open_api: "/open_api",
    modify_open_api: {__MODULE__, :modify_open_api, []}

  def modify_open_api(spec, _, _) do
    %{
      spec
      | info: %{spec.info | title: "MyApp Title JSON API", version: Application.spec(:my_app, :vsn) |> to_string()}
    }
  end
```

## Known issues/limitations

### Swagger UI

SwaggerUI does not properly render recursive types. This affects the examples and type documentation for the `filter` parameter especially.

### Redoc

Redoc does not show all available schemas in the sidebar. This means that some schemas that are referenced only but have no endpoints that refer to them are effectively un-discoverable without downloading the spec and hunting them down yourself.
