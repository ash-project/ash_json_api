# Routing

AshJsonApi provides a set of route helpers that map HTTP requests to Ash actions. Routes are defined inside the `json_api do routes do ... end end` block on either a resource or a domain.

## Route overview

| Route Helper | HTTP Method | Default Path | Primary Action Type | Also Accepts |
|---|---|---|---|---|
| `get` | GET | `/:id` | `:read` | `:action` |
| `index` | GET | `/` | `:read` | `:action` |
| `post` | POST | `/` | `:create` | `:action`, `:read` |
| `patch` | PATCH | `/:id` | `:update` | `:action` |
| `delete` | DELETE | `/:id` | `:destroy` | `:action` |
| `related` | GET | `/:id/<relationship>` | `:read` | — |
| `relationship` | GET | `/:id/relationships/<relationship>` | `:read` | — |
| `post_to_relationship` | POST | `/:id/relationships/<relationship>` | `:update` | — |
| `patch_relationship` | PATCH | `/:id/relationships/<relationship>` | `:update` | — |
| `delete_from_relationship` | DELETE | `/:id/relationships/<relationship>` | `:update` | — |
| `route` | *any* | *required* | `:action` | — |

## Defining routes

Routes can live on the resource or on the domain. Defining them on the domain is the default recommendation — it keeps resources focused on data and actions while the domain acts as the API surface.

### On the domain

```elixir
defmodule MyApp.Support do
  use Ash.Domain, extensions: [AshJsonApi.Domain]

  json_api do
    routes do
      base_route "/tickets", MyApp.Support.Ticket do
        get :read
        index :read
        post :create
        patch :update
        delete :destroy
      end
    end
  end
end
```

`base_route` scopes all nested routes under the given path prefix for the specified resource.

### On the resource

```elixir
defmodule MyApp.Support.Ticket do
  use Ash.Resource, extensions: [AshJsonApi.Resource]

  json_api do
    type "ticket"

    routes do
      base "/tickets"

      get :read
      index :read
      post :create
      patch :update
      delete :destroy
    end
  end
end
```

`base` sets the path prefix for all routes defined on the resource.

## Standard CRUD routes

### `get` — fetch a single record

```elixir
get :read
```

Issues a GET request to `/:id` (by default). Looks up a single record by primary key and returns a JSON:API resource object.

### `index` — list records

```elixir
index :read
```

Issues a GET request to `/` (by default). Returns a JSON:API array of resource objects. Supports filtering, sorting, pagination, and includes.

Options:
- `paginate?` (default `true`) — whether to apply pagination

### `post` — create a record

```elixir
post :create
```

Issues a POST request to `/` (by default). Accepts a JSON:API resource object in the request body and creates a record.

Options:
- `relationship_arguments` — arguments used to edit relationships inline. See the [relationships guide](/documentation/topics/relationships.md).
- `upsert?` (default `false`) — use `upsert?: true` when calling `Ash.create/2`
- `upsert_identity` — which identity to use for the upsert

### `patch` — update a record

```elixir
patch :update
```

Issues a PATCH request to `/:id` (by default). Looks up the record, then applies the update action.

Options:
- `read_action` — the read action used to look up the record before updating
- `relationship_arguments` — arguments used to edit relationships inline

### `delete` — destroy a record

```elixir
delete :destroy
```

Issues a DELETE request to `/:id` (by default). Looks up the record, then destroys it.

Options:
- `read_action` — the read action used to look up the record before destroying

### Custom paths

Any standard route can override its default path:

```elixir
patch :update_email do
  route "/update_email/:id"
end

delete :archive do
  route "/archive/:id"
end
```

## Relationship routes

These routes manage relationships following the JSON:API relationship specification. See the [relationships guide](/documentation/topics/relationships.md) for full details.

```elixir
# GET /tickets/:id/comments — returns related comment resources
related :comments, :read

# GET /tickets/:id/relationships/comments — returns resource identifiers
relationship :comments, :read

# POST /tickets/:id/relationships/comments — add to relationship
post_to_relationship :comments

# PATCH /tickets/:id/relationships/comments — replace relationship
patch_relationship :comments

# DELETE /tickets/:id/relationships/comments — remove from relationship
delete_from_relationship :comments
```

## Generic actions with `route`

The `route` helper exposes generic actions (Ash actions with `type: :action`) over any HTTP method. It is the most flexible routing option.

```elixir
route :get, "/say_hello/:name", :say_hello
route :post, "/trigger_job", :trigger_job
route :delete, "/cancel_job/:id", :cancel_job
```

There are no restrictions on the return type when using `route`. The action can return a string, map, struct, list, or nothing.

### Returning simple values

```elixir
action :say_hello, :string do
  argument :name, :string, allow_nil?: false

  run fn input, _ ->
    {:ok, "Hello, #{input.arguments.name}!"}
  end
end
```

The response body is the raw value: `"Hello, fred!"`

### Returning nothing

Actions with no return type respond with `{"success": true}` and status `201` for POST or `200` for other methods.

```elixir
action :trigger_job do
  run fn _input, _ ->
    :ok
  end
end
```

### `wrap_in_result?`

Wraps the result in a `{"result": <value>}` object:

```elixir
route :get, "/count", :count_things, wrap_in_result?: true
# Response: {"result": 42}
```

### Path parameters and query parameters

Arguments can be supplied via path parameters, query parameters, or the request body.

**Path parameters** — embed `:arg_name` segments in the route:

```elixir
route :get, "/say_hello/:name", :say_hello
# GET /say_hello/fred → name = "fred"
```

**Query parameters** — use the `query_params` option:

```elixir
route :get, "/say_hello", :say_hello, query_params: [:name]
# GET /say_hello?name=fred → name = "fred"
```

For GET requests using `route`, all action arguments are automatically accepted as query parameters even without specifying `query_params`.

**Request body** — for POST/PATCH/DELETE, remaining arguments are read from the JSON body under `data`:

```elixir
route :post, "/greet/:name", :greet
# POST /greet/fred with body {"data": {"greeting": "Hi"}}
# → name = "fred", greeting = "Hi"
```

> ### Conflicting parameters {: .warning}
>
> If the same argument appears in both the path and query string, the request returns a `400` error with an `invalid_query` error code.

## Using generic actions with standard route helpers

The standard route helpers (`get`, `index`, `post`, `patch`, `delete`) also accept generic actions, but they impose **return type constraints** so the response conforms to JSON:API format.

### Return type requirements

| Route Helper | Return Type Constraint |
|---|---|
| `route` | **None** — any return type |
| `get` | `:struct` with `instance_of: __MODULE__` |
| `index` | `{:array, :struct}` with `items: [instance_of: __MODULE__]` |
| `post` | `:struct` with `instance_of: __MODULE__` |
| `patch` | `:struct` with `instance_of: __MODULE__` + path param arguments |
| `delete` | `:struct` with `instance_of: __MODULE__` + path param arguments |

When a generic action is used with `patch` or `delete`, every path parameter (e.g. `:id`) must have a corresponding action argument — since there's no read action to look up the record, the action itself is responsible for finding it.

### Example: `get` with a generic action

```elixir
get :my_custom_get
```

```elixir
action :my_custom_get, :struct do
  constraints instance_of: __MODULE__
  argument :id, :uuid, allow_nil?: false

  run fn input, _ ->
    Ash.get(__MODULE__, input.arguments.id)
  end
end
```

The response is serialized as a standard JSON:API resource object with `type`, `id`, `attributes`, and `relationships`.

### Example: `index` with a generic action

```elixir
index :search
```

```elixir
action :search, {:array, :struct} do
  constraints items: [instance_of: __MODULE__]
  argument :query, :string, allow_nil?: false

  run fn input, _ ->
    # custom search logic
    {:ok, results}
  end
end
```

### Example: `patch` with a generic action

```elixir
patch :fake_update do
  route "/fake_update/:id"
end
```

```elixir
action :fake_update, :struct do
  constraints instance_of: __MODULE__
  argument :id, :uuid, allow_nil?: false

  run fn %{arguments: %{id: id}}, _ ->
    record = Ash.get!(__MODULE__, id)
    {:ok, %{record | name: record.name <> "_updated"}}
  end
end
```

### Example: `delete` with a generic action

```elixir
delete :fake_delete do
  route "/delete_fake/:id"
end
```

```elixir
action :fake_delete, :struct do
  constraints instance_of: __MODULE__
  argument :id, :uuid

  run fn input, _ ->
    Ash.get(__MODULE__, input.arguments.id)
  end
end
```

### When to use `route` vs standard helpers

Use the **standard helpers** when your generic action returns resource instances and you want JSON:API response formatting with `type`, `id`, `attributes`, and `relationships`.

Use **`route`** when:

- Your action returns a non-resource value (string, map, integer, etc.)
- Your action returns nothing (side-effect only)
- You want full control over the HTTP method and path
- You don't need JSON:API resource object formatting in the response

## Common route options

These options are available on all route types:

- `route` — the path for the route (can override the default)
- `action` — the action to call
- `default_fields` — a list of fields to include in the response attributes
- `primary?` (default `false`) — whether this is the default route for link generation
- `metadata` — a function `fn subject, result, request -> map end` for top-level response metadata
- `modify_conn` — a function to modify the Plug conn before responding. See the [modify_conn guide](/documentation/topics/modify-conn.md).
- `query_params` — action arguments to accept as query parameters
- `name` — a globally unique name for this route, used in docs and OpenAPI
- `description` — a human-friendly description for generated documentation (overrides the action description)
- `derive_sort?` (default `true`) — derive a sort parameter from sortable fields
- `derive_filter?` (default `true`) — derive a filter parameter from filterable fields
