defmodule AshJsonApi.JsonApiResource do
  @moduledoc "The entrypoint for adding JSON:API behavior to a resource"

  @callback json_api_type() :: String.t()
  @callback json_api_join_fields() :: Keyword.t()
  @callback json_api_routes() :: [AshJsonApi.AshJsonApiResource.Route.t()]
  @callback json_api_fields() :: [atom]
  @callback json_api_includes() :: Keyword.t()

  defmacro __using__(_) do
    quote do
      import AshJsonApi.JsonApiResource, only: [json_api: 1]
      @behaviour AshJsonApi.JsonApiResource
      Module.register_attribute(__MODULE__, :json_api_routes, accumulate: true)
      Module.register_attribute(__MODULE__, :json_api_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :json_api_relationships, accumulate: true)
      Module.register_attribute(__MODULE__, :json_api_join_fields, accumulate: true)

      @json_api_includes []
      @extensions AshJsonApi.JsonApiResource
      @json_api_type nil
      @json_api_base_route nil
      require AshJsonApi.JsonApiResource
    end
  end

  defmacro json_api(do: body) do
    quote do
      import AshJsonApi.JsonApiResource.Routes, only: [routes: 2]
      import AshJsonApi.JsonApiResource, only: [fields: 1, include: 1, join_fields: 2, type: 1]
      unquote(body)
      import AshJsonApi.JsonApiResource.Routes, only: []
    end
  end

  defmacro type(type) do
    quote do
      @json_api_type unquote(type)
    end
  end

  defmacro include(includes) do
    quote bind_quoted: [includes: includes] do
      @json_api_includes includes
    end
  end

  defmacro join_fields(association, fields) do
    quote bind_quoted: [association: association, fields: fields] do
      @json_api_join_fields {association, fields}
    end
  end

  defmacro fields(fields) do
    quote bind_quoted: [fields: fields] do
      fields
      |> List.wrap()
      |> Enum.map(fn field ->
        @json_api_fields field
      end)
    end
  end

  @doc false
  def before_compile_hook(_env) do
    quote do
      @sanitized_json_api_routes AshJsonApi.sanitize_routes(@relationships, @json_api_routes)

      unless @ash_primary_key == [:id] do
        raise "A json API resource must have a primary key called `:id`"
      end

      def json_api_type do
        @json_api_type
      end

      def json_api_join_fields do
        @json_api_join_fields
      end

      def json_api_routes do
        @sanitized_json_api_routes
      end

      def json_api_fields do
        @json_api_fields
      end

      def json_api_includes do
        @json_api_includes
      end
    end
  end
end
