## Relationship Arguments

You can specify which arguments will modify relationships using `relationship_arguments`, but there are some things to keep in mind.

`relationship_arguments` is a list of arguments that can be edited in the `data.relationships` input.

This is primarily useful for those who want to keep their relationship changes in compliance with the `JSON:API` spec.
If you are not focused on building a fully compliant JSON:API, it is likely far simpler to simply accept arguments
in the `attributes` key and ignore the `data.relationships` input.

If the argument's type is `{:array, _}`, a list of data will be expected. Otherwise, it will expect a single item.

For example:

```elixir
# On a tweets resource

# With a patch route that references the `authors` argument
json_api do
  routes do
    patch :update, relationship_arguments: [:authors]
  end
end

# And an argument by that name in the action
actions do
  update :update do
    argument :authors, {:array, :map}, allow_nil?: false

    change manage_relationship(:authors, type: :append_and_remove) # Use the authors argument to allow changing the related authors on update
  end
end
```

You can then send the value for `authors` in the relationships key, e.g
```json
{
  data: {
    attributes: {
      ...
    },
    relationships: {
      authors: {
        data: [
          {type: "author", id: 1}, // the `type` key is removed when the value is placed into the action, so this input would be `%{"id" => 1}` (`type` is required by `JSON:API` specification)
          {type: "author", id: 2, meta: {arbitrary: 1, keys: 2}}, <- `meta` is JSON:API spec freeform data, so this input would be `%{"id" => 2, "arbitrary" => 1, "keys" => 2}`
        ]
      }
    }
  }
}
```

If you do not include `:authors` in the `relationship_arguments` key, you would supply its value in `attributes`, e.g:

```elixir
{
  data: {
    attributes: {
      authors: {
        {id: 1},
        {id: 2, arbitrary: 1, keys: 2},
      }
    }
  }
}
```

Non-map argument types, e.g `argument :author, :integer` (expecting an author id) work with `manage_relationship`, but not with
JSON:API, because it expects `{"type": _type, "id" => id}` for relationship values. To support non-map arguments in `relationship_arguments`,
instead of `:author`, use `{:id, :author}`. This works for `{:array, _}` type arguments as well, so the value would be a list of ids.
