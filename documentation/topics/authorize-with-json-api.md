# Authorize with AshJsonApi

By default, `authorize?` in the domain is set to true. To disable authorization entirely for a given domain in json_api, use:

```elixir
json_api do
  authorize? false
end
```

This is typically only necessary for testing purposes.

If you are doing authorization, you'll need to provide an `actor`.

## Setting the actor manually

If you are using AshAuthentication, this will be done for you. To set the `actor` for authorization, you'll need to add an `actor` key to the
`conn`. Typically, you would have a plug that fetches the current user and uses `Ash.PlugHelpers.set_actor/2` to set the actor in the `conn` (likewise with `Ash.PlugHelpers.set_tenant/2`).

```elixir
defmodule MyAppWeb.Router do
  pipeline :api do
    # ...
    plug :get_actor_from_token
  end

  def get_actor_from_token(conn, _opts) do
     with ["" <> token] <- get_req_header(conn, "authorization"),
         {:ok, user, _claims} <- MyApp.Guardian.resource_from_token(token) do
      conn
      |> Ash.PlugHelpers.set_actor(user)
    else
    _ -> conn
    end
  end
end
```
