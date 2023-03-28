# Open API

## Use with Phoenix

To set up the open api endpoints for your application, first include the `:open_api_spex` dependency:

```elixir
{:open_api_spex, "~> 3.16"},
```

Then in the module where you call `use AshJsonApi.Api.Router` add the following option:

```elixir
use AshJsonApi.Api.Router, apis: [...], open_api: "/open_api"
```

Finally, you can use utilities provided by `open_api_spex` to show UIs for your api. Be sure to put your `forward` call last, if you are putting your api at a sub-path.

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

To set up the open api endpoints for your application, first include the `:open_api_spex` and `:redoc_ui_plug` dependency:

```elixir
{:open_api_spex, "~> 3.16"},
{:redoc_ui_plug, "~> 0.2.1"},
```

Then in the module where you call `use AshJsonApi.Api.Router` add the following option:

```elixir
use AshJsonApi.Api.Router, apis: [...], open_api: "/open_api"
```

Finally, you can use utilities provided by `open_api_spex` to show UIs for your api. Be sure to put your `forward` call last, if you are putting your api at a sub-path.

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

