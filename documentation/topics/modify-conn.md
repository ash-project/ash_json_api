# Using modify_conn to Customize HTTP Responses

The `modify_conn` option in AshJsonApi allows you to customize the HTTP response by modifying the Plug connection before it's sent to the client. This is useful for setting custom headers, cookies, or making any other modifications to the response based on the action's result.

## Overview

The `modify_conn` option is available on all route types in AshJsonApi:
- `get`
- `index`
- `post`
- `patch`
- `delete`
- `related`
- `relationship`
- `post_to_relationship`
- `patch_relationship`
- `delete_from_relationship`
- `route` (generic action routes)

## Function Signature

The `modify_conn` function receives four arguments:

```elixir
modify_conn(fn conn, subject, result, request ->
  # Your modifications here
  conn
end)
```

### Arguments

1. **`conn`** - The Plug.Conn struct representing the HTTP connection
2. **`subject`** - The query, changeset, or action_input that was executed
3. **`result`** - The result of the action that was performed
4. **`request`** - The AshJsonApi request object containing route and other request information

## Common Use Cases

### Setting Custom Headers

One of the most common uses for `modify_conn` is to set custom headers based on the action result:

```elixir
defmodule MyApp.Post do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshJsonApi.Resource]

  json_api do
    routes do
      base "/posts"
      
      post :create do
        modify_conn(fn conn, _subject, result, _request ->
          conn
          |> Plug.Conn.put_resp_header("x-resource-id", to_string(result.id))
          |> Plug.Conn.put_resp_header("x-created-at", to_string(result.created_at))
        end)
      end
    end
  end
end
```

### Authentication Headers

A common pattern is to return authentication tokens in response headers after certain actions:

```elixir
defmodule MyApp.User do
  use Ash.Resource,
    domain: MyApp.Domain,
    extensions: [AshJsonApi.Resource]

  json_api do
    routes do
      base "/users"
      
      post :sign_in do
        route "/sign_in/:id"
        
        modify_conn(fn conn, _subject, result, _request ->
          case result do
            %{__metadata__: %{token: token}} when not is_nil(token) ->
              Plug.Conn.put_resp_header(conn, "authorization", "Bearer #{token}")
            
            _ ->
              conn
          end
        end)
      end
    end
  end
end
```

### Cache Control Headers

Control caching behavior for specific routes:

```elixir
get :read do
  modify_conn(fn conn, _subject, result, _request ->
    cache_control = 
      if result.public? do
        "public, max-age=3600"
      else
        "private, no-cache"
      end
    
    Plug.Conn.put_resp_header(conn, "cache-control", cache_control)
  end)
end
```


### Rate Limiting Headers

Return rate limiting information to clients:

```elixir
index :read do
  modify_conn(fn conn, _subject, _result, request ->
    # Assume we have rate limiting info in the conn assigns
    rate_limit_info = conn.assigns[:rate_limit] || %{}
    
    conn
    |> Plug.Conn.put_resp_header("x-ratelimit-limit", to_string(rate_limit_info[:limit] || 100))
    |> Plug.Conn.put_resp_header("x-ratelimit-remaining", to_string(rate_limit_info[:remaining] || 100))
    |> Plug.Conn.put_resp_header("x-ratelimit-reset", to_string(rate_limit_info[:reset] || 0))
  end)
end
```

### Pagination Headers

Add pagination information to list responses:

```elixir
index :read do
  modify_conn(fn conn, _subject, result, _request ->
    case result do
      %Ash.Page.Offset{} = page ->
        conn
        |> Plug.Conn.put_resp_header("x-total-count", to_string(page.count || 0))
        |> Plug.Conn.put_resp_header("x-page-limit", to_string(page.limit || 0))
        |> Plug.Conn.put_resp_header("x-page-offset", to_string(page.offset || 0))
      
      _ ->
        conn
    end
  end)
end
```

## Best Practices

1. **Always return the conn** - The function must return the modified connection
2. **Handle nil values** - Be defensive about accessing nested data that might be nil
3. **Keep it simple** - Complex logic should be in your actions, not in `modify_conn`
4. **Be consistent** - Use similar header naming conventions across your API
5. **Document your headers** - Make sure API consumers know about custom headers

## Integration with Other Features

The `modify_conn` function works seamlessly with other AshJsonApi features:

- It runs after authorization checks
- It has access to the full result, including any data loaded via includes
- It can access metadata set by your actions
- It works with all route types, including relationship routes
