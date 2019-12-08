# AshJsonApi

AshJsonApi allows you to take resources created with [Ash](https://github.com/ash-project/ash) and build complete JSON:API compliant endpoints with just a few lines of code.

Here is how it fits into an app and what it does:
![Architecture Sketch](documentation/architecture_sketch.jpg)

As you can see, Ash takes care of all of the data related work for a request (CRUD, Sorting, Filtering, Pagination, Side Loading, and Authorization) while AshJsonApi more or less replaces controllers and serializers.

The beauty of putting all of that data functionality into a non-web layer (Ash) is that it can be used in many contexts. A JSON:API is one context - but there are others such as GraphQL or just using an Ash Resource from other code within an Application. The decoupling of the web from data layers is why AshJsonApi is it's own hex package, as opposed to just a module within [Ash](https://github.com/ash-project/ash).


## Installation
AshJsonApi is only useful once you have installed [Ash](https://github.com/ash-project/ash), so do that first. Then when you are ready, add AshJsonApi to your application’s mix.exs file:

```elixir
{:ash_json_api, path: "../ash_json_api"}
```
And then execute:

```shell
mix deps.get
```

## Usage
Assume you have already built a resource using [Ash](https://github.com/ash-project/ash) such as this Post resource:
```elixir
defmodule Post do
  use Ash.Resource, name: "posts", type: "post"
  use AshJsonApi.JsonApiResource
  use Ash.DataLayer.Postgres

  actions do
    read(:default,
      rules: [
        allow(:static, result: true)
      ]
    )

    create(:default,
      rules: [
        allow(:static, result: true)
      ]
    )
  end

  attributes do
    attribute(:name, :string)
  end

  relationships do
    belongs_to(:author, Author)
  end
end
```

As you can see, the resource takes care of interacting with the database, setting up attributes and relationships, as well as specifying actions (CRUD) that can be performed on the resource. What is now needed is to add a configuration for how this resource will interact with JSON:API

```elixir
defmodule Post do
  ...
  
  json_api do
    routes do
      get(:default)
      index(:default)
    end

    fields [:name]
  end

  ...
```

## TODO
* Validate no overlapping routes
* Make it so that `mix phx.routes` can print the routes from a `Plug.Router` so that our routes can be printed too.
* Validate all fields exist that are in the fields list
* Validate includes
* Do the whole request in a transaction *all the time*
* validate incoming relationship updates have the right type
* validate that there are only `relationship_routes` for something that is in `relationships`, and that the `relationship` is marked as editable (when we implement marking them as editable or not)
* All kinds of spec compliance, like response codes and error semantics
* Should implement a complete validation step, that first checks for a valid request according to json api, then validates against the resource being requested
* Logging should be routed through ash so it can be configured/customized
* Set logger metadata when we parse the request
* Errors should have about pages
* Create the ability to dynamically create a resource in a test
* The JSON schema for test was edited a bit to remove referenes to `uri-reference`, because either our parser was doing them wrong, or we have to do them in a really ugly way that I'd rather just not do. https://github.com/hrzndhrn/json_xema/issues/26
