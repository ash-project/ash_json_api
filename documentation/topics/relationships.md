# Relationships

You can specify which arguments will modify relationships using `relationship_arguments`, but there are some things to keep in mind.

`relationship_arguments` is a list of arguments that can be edited in the `data.relationships` input.

This is primarily useful for those who want to keep their relationship changes in compliance with the `JSON:API` spec.
If you are not focused on building a fully compliant JSON:API, it is likely far simpler to simply accept arguments
in the `attributes` key and ignore the `data.relationships` input.

If the argument's type is `{:array, _}`, a list of data will be expected. Otherwise, it will expect a single item.

Everything in this guide applies to routs defined on the domain as well.

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

## Relationship Manipulation Routes

You can also specify routes that are dedicated to manipulating relationships. We generally suggest the above approach, but JSON:API spec also allows for dedicated relationship routes. For example:

```elixir
routes do
  ...
  # use `post_to_relationship` when the operation is additive
  post_to_relationship :add_author, action: :add_author
  # use `patch_relationship` when the operation is both additive and subtractive
  # use `delete_from_relationship` when the operation is subtractive
end
```

This will use an action on the source resource, (by default the primary update), and expects it to take an argument with the corresponding name. Additionally, it must have a `change manage_relationship` that uses that attribute. For example:

```elixir
update :add_author do
  argument :author, :map

  change manage_relationship(:author, type: :append)
end
```
