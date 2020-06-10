# AshJsonApi

![Elixir CI](https://github.com/ash-project/ash_json_api/workflows/Elixir%20CI/badge.svg)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Coverage Status](https://coveralls.io/repos/github/ash-project/ash_json_api/badge.svg?branch=master)](https://coveralls.io/github/ash-project/ash_json_api?branch=master)
[![Hex version badge](https://img.shields.io/hexpm/v/ash_json_api.svg)](https://hex.pm/packages/ash_json_api)

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
    routes "/posts" do
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
