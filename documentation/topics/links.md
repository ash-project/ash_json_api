# Links

In JSON:API, there are various pre-specified links.

## Self links to routes

Whenever you hit a route, there will be a `self` link in the top-level `links` object that points to the current request url.

## Pagination links on index routes

There will be `first`, `last`, `prev`, and `next` links on paginatable index routes, allowing clients to navigate through the pages of results.

## Self links on individual entities

In order to get a self link generated for an individual entity, you must designate one of your `get` routes as `primary? true`. For example:

```elixir
get :read, primary?: true
```

Then, each entity will have a `self` link in its `links` key.

## Related links

### Relationship Self Links

Relationship self links are links to endpoints that return only the linkage, _not_ the actual data of the related entities. To generate a relationship self link for a relationship, mark one of your `relationship` routes as `primary? true`. For example:

```elixir
relationship :comments, :read, primary?: true
```

### Relationship Related Links

Relationship _related_ links, on the other hand, are endpoints that return the related entities themselves, acting as modified index routes over the destination of the relationship. To generate one of these, mark one of your `related` routes as `primary? true`. For example:

```elixir
related :comments, :read, primary?: true
```
