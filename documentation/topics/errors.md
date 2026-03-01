<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Errors

AshJsonApi converts Ash errors into [JSON:API error objects](https://jsonapi.org/format/#errors). This topic covers how that conversion works, how to customize it, and the available configuration options.

## Error Format

Every error response follows the JSON:API error object format:

```json
{
  "errors": [
    {
      "id": "a1b2c3d4-...",
      "status": "422",
      "code": "invalid_attribute",
      "title": "InvalidAttribute",
      "detail": "must be present",
      "source": {
        "pointer": "/data/attributes/name"
      }
    }
  ]
}
```

## The `AshJsonApi.ToJsonApiError` Protocol

AshJsonApi uses the `AshJsonApi.ToJsonApiError` protocol to convert Ash exceptions into `AshJsonApi.Error` structs. Built-in implementations are provided for common Ash errors such as `Ash.Error.Changes.InvalidChanges`, `Ash.Error.Query.NotFound`, `Ash.Error.Forbidden.Policy`, and others.

If your application raises a custom Ash exception and you want it to produce a specific JSON:API error, implement the protocol:

```elixir
defimpl AshJsonApi.ToJsonApiError, for: MyApp.Errors.PaymentRequired do
  def to_json_api_error(error) do
    %AshJsonApi.Error{
      id: Ash.UUID.generate(),
      status_code: 402,
      code: "payment_required",
      title: "PaymentRequired",
      detail: error.message,
      meta: %{}
    }
  end
end
```

The `AshJsonApi.Error` struct has the following fields:

| Field | Description |
|---|---|
| `id` | Unique identifier for this error occurrence |
| `status_code` | HTTP status code (integer) |
| `code` | Machine-readable error code string |
| `title` | Human-readable error title |
| `detail` | Human-readable explanation specific to this occurrence |
| `source_pointer` | JSON Pointer to the source of the error (e.g. `/data/attributes/name`) |
| `source_parameter` | Query parameter that caused the error |
| `meta` | Arbitrary metadata map |
| `about` | Link to further information about this error |
| `log_level` | Log level for this error (default: `:debug`) |
| `internal_description` | Internal description used for logging, not sent to clients |

## Transforming Errors with `error_handler`

The `error_handler` domain option lets you intercept and transform any `AshJsonApi.Error` struct before it is sent to the client. This is useful for sanitizing error messages, adding metadata, translating error text, or applying any other cross-cutting transformation.

Configure it in your domain as an MFA:

```elixir
defmodule MyApp.Domain do
  use Ash.Domain, extensions: [AshJsonApi.Domain]

  json_api do
    error_handler {MyApp.JsonApiErrorHandler, :handle_error, []}
  end
end
```

The handler receives the `AshJsonApi.Error` struct and a context map, and must return a modified `AshJsonApi.Error` struct:

```elixir
defmodule MyApp.JsonApiErrorHandler do
  def handle_error(error, _context) do
    # Sanitize internal details from 500 errors
    if error.status_code >= 500 do
      %{error | detail: "An internal error occurred. Please try again later."}
    else
      error
    end
  end
end
```

The context map contains:

| Key | Description |
|---|---|
| `:domain` | The domain module handling the request |
| `:resource` | The resource module associated with the request (may be `nil`) |

### Example: Translating Error Messages

```elixir
defmodule MyApp.JsonApiErrorHandler do
  def handle_error(error, _context) do
    %{error | detail: MyApp.Gettext.translate_error(error.code, error.detail)}
  end
end
```

### Example: Adding Custom Metadata

```elixir
defmodule MyApp.JsonApiErrorHandler do
  def handle_error(error, %{domain: domain}) do
    %{error | meta: Map.put(error.meta || %{}, :api_version, "v2")}
  end
end
```

### Example: Context-Specific Handling

```elixir
defmodule MyApp.JsonApiErrorHandler do
  def handle_error(error, %{resource: resource}) do
    case resource do
      MyApp.PaymentResource ->
        %{error | detail: MyApp.Payments.format_error(error)}

      _ ->
        error
    end
  end
end
```

## Configuration Options

### `show_raised_errors?`

By default, if an error is *raised* (i.e. an unexpected exception, not a structured Ash error), AshJsonApi returns a generic error message with only a UUID for reference. This prevents leaking internal implementation details.

Set `show_raised_errors? true` to include the full exception in the response — useful during development:

```elixir
json_api do
  show_raised_errors? true
end
```

### `log_errors?`

Controls whether errors are logged. Defaults to `true`.

```elixir
json_api do
  log_errors? false
end
```

### Policy Breakdown Details

By default, authorization failures return a generic "forbidden" message. To include a breakdown of which policies failed (useful for debugging), set this in your application config:

```elixir
# config/dev.exs
config :ash_json_api, :policies, show_policy_breakdowns?: true
```

> **Warning:** Do not enable this in production, as it may expose details about your authorization logic.
