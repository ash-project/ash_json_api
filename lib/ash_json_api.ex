defmodule AshJsonApi do
  @moduledoc """

  ![Logo](https://github.com/ash-project/ash/blob/master/logos/cropped-for-header.png?raw=true)

  An ash extension for building a JSON:API with ash resources.

  ## Usage

  Assume you have already built a resource using [Ash](https://github.com/ash-project/ash) such as this Post resource:

  ```elixir
  defmodule Post do
    use Ash.Resource,
      data_layer: Ash.DataLayer.Postgres

    actions do
      read :default

      create :default
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
    use Ash.Resource,
      data_layer: AshPostgres,
      extensions: [AshJsonApi.Resource]

    ...

    json_api do
      routes do
        base "/posts"
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

  Then, update your API with the API extension and configuration:


  ```elixir
  defmodule MyApp.Api do
    use Ash.Api, extensions: [AshJsonApi.Api]

    json_api do
      ...
    end

  end
  ```

  See `AshJsonApi.Api` and `AshJsonApi.Resource` for the DSL documentation.
  """
  alias Ash.Dsl.Extension

  def route(resource, criteria \\ %{}) do
    resource
    |> routes()
    |> Enum.find(fn route ->
      Map.take(route, Map.keys(criteria)) == criteria
    end)
  end

  def type(resource) do
    Extension.get_opt(resource, [:json_api], :type)
  end

  def routes(resource) do
    Extension.get_entities(resource, [:json_api, :routes])
  end

  def fields(resource) do
    resource
    |> Extension.get_opt([:json_api], :fields)
    |> List.wrap()
  end

  def includes(resource) do
    Extension.get_opt(resource, [:json_api], :includes)
  end

  def prefix(api) do
    Extension.get_opt(api, [:json_api], :prefix)
  end

  def serve_schema?(api) do
    Extension.get_opt(api, [:json_api], :serve_schema?)
  end

  def authorize?(api) do
    Extension.get_opt(api, [:json_api], :authorize?)
  end

  def router!(api) do
    case Code.ensure_compiled(api) do
      {:module, _module} ->
        :persistent_term.get({api, :ash_json_api, :router}, nil)

      error ->
        raise "#{inspect(api)} was not compiled: #{inspect(error)}"
    end
  end

  def base_route(resource) do
    Extension.get_opt(resource, [:json_api, :routes], :base)
  end
end
