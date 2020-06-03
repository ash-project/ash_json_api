# AshJsonApi

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

AshJsonApi allows you to take resources created with [Ash](https://github.com/ash-project/ash) and build complete JSON:API compliant endpoints with just a few lines of code.

This is what AshJsonApi does:

1. Route Creation: AshJsonApi defines routes and actions in your app based on resource configurations
2. Deserialization: When an incoming HTTP request hits a AshJsonApi defined route/action, AshJsonApi will parse it from /api/users?filter[admin]=true into an Ash Action Ash.read(:user, filter: [admin: true])
3. Query Execution: AshJsonApi then executes the parsed Ash Action (this is the integration point between AshJsonApi and Ash Core, where Ash Actions are defined)
4. Serialization: AshJsonApi then serializes the result of the Ash Action into JSON API objects.
5. Response: AshJsonApi then sends this JSON back to the client
6. Schema Generation: AshJsonApi generates a machine-readable JSON Schema of your entire API and a route/action that can serve it

Here is how it fits into an app and what it does:
![Architecture Sketch](documentation/architecture_sketch.jpg)

As you can see, Ash takes care of all of the data related work for a request (CRUD, Sorting, Filtering, Pagination, Side Loading, and Authorization) while AshJsonApi more or less replaces controllers and serializers.

The beauty of putting all of that data functionality into a non-web layer (Ash) is that it can be used in many contexts. A JSON:API is one context - but there are others such as GraphQL or just using an Ash Resource from other code within an Application. The decoupling of the web from data layers is why AshJsonApi is it's own hex package, as opposed to just a module within [Ash](https://github.com/ash-project/ash).

## Usage

Assume you have already built a resource using [Ash](https://github.com/ash-project/ash) such as this Post resource:

```elixir
defmodule Post do
  use Ash.Resource, name: "posts", type: "post"
  use AshJsonApi.JsonApiResource
  use Ash.DataLayer.Postgres

  actions do
    read :default,
      rules: [
        authorize_if: asert_attribute(:admin, true)
      ]

    create :default,
      rules: [
        authorize_if: user_attribute(:admin, true)
      ]
  end

  attributes do
    attribute :name, :string
  end

  relationships do
    belongs_to :author, Author
  end
end
```

As you can see, the resource takes care of interacting with the database, setting up attributes and relationships, as well as specifying actions (CRUD) that can be performed on the resource. What is now needed is to add a configuration for how this resource will interact with JSON:API

```elixir
defmodule Post do
  ...

  json_api do
    routes do
      # Add a `GET /posts/:id` route, that calls into the :read action called :default
      get :default
      # Add a `GET /posts` route, that calls into the :read action called :default
      index :default
    end

    # Expose these attributes in the API
    fields [:name]
  end

  ...
```

- Validate no overlapping routes (and that route order never causes mishaps, the current implementation just sorts by the number of colons, which may be enough?)
- Make it so that `mix phx.routes` can print the routes from a `Plug.Router` so that our routes can be printed too.
- Validate all fields exist that are in the fields list
- Validate includes
- Support many to many relationships additional fields on resource identifiers. Some code exists to parse them out of the request,
  but we need code to encode those fields and code to accept/deal with them in ash core.
- Do the whole request in a transaction _all the time_
- validate incoming relationship updates have the right type
- validate that there are only `relationship_routes` for something that is in `relationships`, and that the `relationship` is marked as editable (when we implement marking them as editable or not)
- All kinds of spec compliance, like response codes and error semantics
- Should implement a complete validation step, that first checks for a valid request according to json api, then validates against the resource being requested
- Logging should be routed through ash so it can be configured/customized
- Set logger metadata when we parse the request
- Errors should have about pages
- Create the ability to dynamically create a resource in a test
- The JSON schema for test was edited a bit to remove referenes to `uri-reference`, because either our parser was doing them wrong, or we have to do them in a really ugly way that I'd rather just not do. https://github.com/hrzndhrn/json_xema/issues/26
- Support different member name transformers
- Support turning off authentication via api config
- set up pagination maximums and defaults by resource
- validate our spec compliant handling of content-type and accept request headers. Phoenix recommends lower case, but spec requires uppercase
- wire up error handling with ash errors
- right now we apply a sort for pagination. We should make sure that when resources are paginated, they have a consistent sort, probably via whatever we do for pagination in core ash
- the 404 controller needs to render a real error
- Invalid includes errors should be rendered in the same format they were provided(or at least in json api format)
- Support filtering included records via `filter[included]`
- Support nested boolean filters
- Consider validating the `fields` dsl option (even though that may be moved to actions soon)
- Support composite primary keys, and configuring the `id` field in general
- the relationship route builders should take into account the kind of relationship. It is scaffolding routes that don't make sense for many to many relationships. Routing in general should improve, especially around relationships
- Figure out the json schema for content-type/accept
- Support for links in the serializer was dropped at some point, we need to add it back
- validate includes in the json schema
- add basic type validations to json schema, perhaps delegating to an optional callback on ash type to give a json schema format for a value
- relationship filters supported/formatted properly in the json schema
