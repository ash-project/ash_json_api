defmodule AshJsonApi.JsonApi.Routes do
  defmacro routes(do: body) do
    quote do
      import AshJsonApi.JsonApi.Routes
      unquote(body)
      import AshJsonApi.JsonApi.Routes, only: []
    end
  end

  # TODO: Validate `primary?` by type
  defmacro get(action, opts \\ []) do
    quote bind_quoted: [action: action, opts: opts] do
      route = opts[:route] || "/:id"

      unless Enum.find(Path.split(route), fn part -> part == ":id" end) do
        raise "Route for get action *must* contain an `:id` path parameter"
      end

      @json_api_routes AshJsonApi.JsonApi.Route.new(
                         route:
                           AshJsonApi.JsonApi.Routes.prefix(
                             route,
                             @name,
                             Keyword.get(opts, :prefix?, true)
                           ),
                         action: action || :get,
                         primary?: opts[:primary?] || false
                       )
    end
  end

  defmacro index(action, opts \\ []) do
    quote bind_quoted: [action: action, opts: opts] do
      route = opts[:route] || "/"

      @json_api_routes AshJsonApi.JsonApi.Route.new(
                         route:
                           AshJsonApi.JsonApi.Routes.prefix(
                             route,
                             @name,
                             Keyword.get(opts, :prefix?, true)
                           ),
                         action: action,
                         primary?: opts[:primary?] || false
                       )
    end
  end

  # TODO: Related resource route ought to use a get action on the destination resource
  # but with some kind of hook and/or w/ a "special" filter applied.

  defmacro relationship_routes(relationship, opts \\ []) do
    quote bind_quoted: [relationship: relationship, opts: opts] do
      related(relationship, opts)
      relationship(relationship, opts)
    end
  end

  defmacro related(relationship, opts \\ []) do
    quote bind_quoted: [relationship: relationship, opts: opts] do
      route = opts[:route] || ":id/#{relationship}"

      unless Enum.find(Path.split(route), fn part -> part == ":id" end) do
        raise "Route for get action *must* contain an `:id` path parameter"
      end

      @json_api_routes AshJsonApi.JsonApi.Route.new(
                         route:
                           AshJsonApi.JsonApi.Routes.prefix(
                             route,
                             @name,
                             Keyword.get(opts, :prefix?, true)
                           ),
                         primary?: opts[:primary?] || true,
                         action: :get_related,
                         relationship: relationship
                       )
    end
  end

  defmacro relationship(relationship, opts \\ []) do
    quote bind_quoted: [relationship: relationship, opts: opts] do
      route = opts[:route] || ":id/relationships/#{relationship}"

      unless Enum.find(Path.split(route), fn part -> part == ":id" end) do
        raise "Route for get action *must* contain an `:id` path parameter"
      end

      @json_api_routes AshJsonApi.JsonApi.Route.new(
                         route:
                           AshJsonApi.JsonApi.Routes.prefix(
                             route,
                             @name,
                             Keyword.get(opts, :prefix?, true)
                           ),
                         primary?: opts[:primary?] || true,
                         action: :get_relationship,
                         relationship: relationship
                       )
    end
  end

  # TODO: related_resource_routes
  # TODO: relationship_routes

  def prefix(route, name, true) do
    full_route = "/" <> name <> "/" <> String.trim_leading(route, "/")

    String.trim_trailing(full_route, "/")
  end

  def prefix(route, _name, _) do
    route
  end
end
