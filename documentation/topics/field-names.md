<!--
SPDX-FileCopyrightText: 2020 Zach Daniel

SPDX-License-Identifier: MIT
-->

# Transforming Field Names

By default, AshJsonApi uses the Ash resource's attribute, relationship, calculation, and aggregate names directly as JSON:API field names. This means a `:first_name` attribute appears as `"first_name"` in requests and responses. The `field_names` and `argument_names` DSL options let you change this — for example, to expose a camelCase API while keeping snake_case internals.

These options affect **every** place a field or argument name appears: serialization output, request body parsing, sort and filter parameters, sparse fieldsets, error source pointers, relationship keys, JSON Schema, and OpenAPI spec generation.

## Renaming fields

### Built-in transformers

Use `:camelize` or `:dasherize` for common conventions:

```elixir
field_names :camelize  # first_name → firstName
field_names :dasherize # first_name → first-name
```

### Keyword list

Use a keyword list to rename specific fields:

```elixir
json_api do
  type "user"

  field_names first_name: :firstName, last_name: :lastName
end
```

A `GET /users/:id` response would then return:

```json
{
  "data": {
    "type": "user",
    "id": "...",
    "attributes": {
      "firstName": "Ada",
      "lastName": "Lovelace"
    }
  }
}
```

Fields not listed in the keyword list keep their original names.

### Function

Use a 1-arity function for a blanket transformation. This is useful for converting all field names to camelCase:

```elixir
json_api do
  type "user"

  field_names fn name ->
    camelized = name |> to_string() |> Macro.camelize()
    {first, rest} = String.split_at(camelized, 1)
    String.downcase(first) <> rest
  end
end
```

This applies to all public attributes, relationships, calculations, and aggregates on the resource.

## Renaming action arguments

Action arguments (the values sent in the request body under `data.attributes`) can also be renamed with `argument_names`.

### Keyword list

Provide a nested keyword list keyed by action name:

```elixir
json_api do
  type "post"

  argument_names [
    create: [publish_at: :publishAt],
    update: [publish_at: :publishAt]
  ]
end
```

### Function

Use a 2-arity function that receives `(action_name, argument_name)`:

```elixir
json_api do
  type "post"

  argument_names fn _action_name, arg_name ->
    camelized = arg_name |> to_string() |> Macro.camelize()
    {first, rest} = String.split_at(camelized, 1)
    String.downcase(first) <> rest
  end
end
```

The `action_name` parameter lets you apply different mappings per action if needed.

## Where renaming is applied

Once configured, name mapping is applied consistently across:

- **Serialization** — response `attributes` and `relationships` objects use the renamed keys.
- **Request body parsing** — `data.attributes` keys in POST/PATCH bodies are expected under their renamed forms.
- **Sort parameters** — `?sort=firstName` works when `:first_name` is renamed to `firstName`.
- **Filter parameters** — `?filter[firstName]=Ada` maps back to the `:first_name` attribute via a ref transformer passed to `Ash.Filter.parse_input/3`.
- **Sparse fieldsets** — `?fields[user]=firstName,lastName` selects the renamed fields.
- **Error source pointers** — validation errors point to `/data/attributes/firstName` instead of `/data/attributes/first_name`.
- **JSON Schema & OpenAPI** — generated schemas use the renamed property names.

## Combining both options

You can use `field_names` and `argument_names` together. A common pattern is to camelCase everything:

```elixir
json_api do
  type "user"

  field_names :camelize
  argument_names :camelize
end
```
