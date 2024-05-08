## Upgrading to AshJsonApi to 1.0

Two major things have changed in `AshJsonApi` 1.0.

## Errors

The error handling has been revamped to be more in line with patterns around Ash and AshGraphql. To implement custom errors, or to enable additional Ash errors to be displayed by AshJsonApi, you will implement the `AshJsonApi.ToJsonApiError` protocol. Here is how its done for one of the builtin errors:

```elixir
defimpl AshJsonApi.ToJsonApiError, for: Ash.Error.Changes.InvalidChanges do
  def to_json_api_error(error) do
    %AshJsonApi.Error{
      id: Ash.UUID.generate(),
      status_code: AshJsonApi.Error.class_to_status(error.class),
      code: "invalid",
      title: "Invalid",
      source_parameter: to_string(error.field),
      detail: error.message,
      meta: Map.new(error.vars)
    }
  end
end
```

## Relationship Routes

Previously, AshJsonApi called `Ash.Changeset.manage_relationship` on the changeset built for the action. Now, _you_ have to define the argument and manage_relationship yourself. See the relationships guide for more.

## `Ash.Api` is now `Ash.Domain` in Ash 3.0

Your Router module file (the module that has `use AshJsonApi.Router` in it) will need all references to `api` updated to be `domain`. eg.

```elixir
defmodule MyApp.MyApi.Router do
  use AshJsonApi.Router,
    domains: [MyApp.Domain1, MyApp.Domain2],
    ...
```
