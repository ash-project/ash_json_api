<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

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

To customize the main values of the OpenAPI spec, a few options are available:

```elixir
  use AshJsonApi.Router,
    domains: [...],
    open_api: "/open_api",
    open_api_title: "Title",
    open_api_version: "1.0.0",
    open_api_servers: ["http://domain.com/api/v1"]
```

If `:open_api_servers` is not specified, a default server is automatically derived from your app's Phoenix endpoint, as retrieved from inbound connections on the `open_api` HTTP route.

In case an active connection is not available, for example when generating the OpenAPI spec via CLI, you can explicitely specify a reference to the Phoenix endpoint:

```elixir
  use AshJsonApi.Router,
    domains: [...],
    open_api: "/open_api",
    phoenix_endpoint: MyAppWeb.Endpoint
```

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

## Generate spec files via CLI

You can write the OpenAPI spec file to disk using the Mix tasks provided by [OpenApiSpex](https://github.com/open-api-spex/open_api_spex).

Supposing you have setup AshJsonApi as:

```elixir
defmodule MyAppWeb.AshJsonApi
  use AshJsonApi.Router, domains: [...], open_api: "/open_api"
end
```

you can generate the files with:

```sh
mix openapi.spec.json --spec MyAppWeb.AshJsonApi
mix openapi.spec.yaml --spec MyAppWeb.AshJsonApi
```

> ### Setting a route prefix for generated files {: .warning}
>
> The route prefix in normal usage is automatically inferred, but when generating files
> we will use the `prefix` option set in the `json_api` section of the relevant `Ash.Domain` module.

To generate the YAML file you need to add the ymlr dependency.

```elixir
def deps do
  [
    {:ymlr, "~> 2.0"}
  ]
end
```

You can also use the `--check` option to confirm that your checked in spec file(s) match.

```sh
mix openapi.spec.json --spec MyAppWeb.AshJsonApiRouter --check
mix openapi.spec.yaml --spec MyAppWeb.AshJsonApiRouter --check
```

## Using this file in production

To avoid generating the spec every time your open_api endpoint is hit, you can use
the `open_api_file` option. Ensure that it points to an existing `.json` file.
You will almost certainly want to do this only for production so that the schema
is generated dynamically in dev, but served statically in production.

```elixir
open_api_file =
  if Mix.env() == :prod do
    "priv/static/open_api.json"
  else
    nil
  end

use AshJsonApi.Router,
  domains: [...],
  open_api: "/open_api",
  modify_open_api: {__MODULE__, :modify_open_api, []},
  open_api_file: open_api_file
```

## Known issues/limitations

### Swagger UI

SwaggerUI does not properly render recursive types. This affects the examples and type documentation for the `filter` parameter especially.

### Redoc

Redoc does not show all available schemas in the sidebar. This means that some schemas that are referenced only but have no endpoints that refer to them are effectively un-discoverable without downloading the spec and hunting them down yourself.
