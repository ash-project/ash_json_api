# AshJsonApi

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

## Installation

TODO

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

## TODO

- Validate no overlapping routes
- Make it so that `mix phx.routes` can print the routes from a `Plug.Router` so that our routes can be printed too.
- Validate all fields exist that are in the fields list
- Validate includes
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
