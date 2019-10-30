defmodule AshJsonApi.RouteBuilder do
  defmacro build_resource_routes(resource) do
    quote bind_quoted: [resource: resource] do
      AshJsonApi.RouteBuilder.build_routes(resource)
    end
  end

  defmacro build_routes(resource) do
    quote bind_quoted: [resource: resource] do
      for %{route: route, action: action_name, relationship: relationship_name} <-
            AshJsonApi.routes(resource) do
        with {:action, nil} <- {:action, Ash.action(resource, action_name)},
             {:relationship, nil} <-
               {:relationship, Ash.relationship(resource, relationship_name)} do
          raise "No matching action or relationship!"
        else
          {:action, %{type: :get} = action} ->
            get(route,
              to: AshJsonApi.Controllers.Get,
              init_opts: [resource: resource, action: action]
            )

          {:action, %{type: :index} = action} ->
            get(route,
              to: AshJsonApi.Controllers.Index,
              init_opts: [resource: resource, action: action]
            )

          {:relationship, %{type: :has_one} = relationship} ->
            get(route,
              to: AshJsonApi.Controllers.GetHasOne,
              init_opts: [resource: resource, relationship: relationship]
            )

          {:relationship, %{type: :belongs_to} = relationship} ->
            get(route,
              to: AshJsonApi.Controllers.GetBelongsTo,
              init_opts: [resource: resource, relationship: relationship]
            )

          {:relationship, %{type: :has_many} = relationship} ->
            get(route,
              to: AshJsonApi.Controllers.GetHasMany,
              init_opts: [resource: resource, relationship: relationship]
            )

          {:relationship, %{type: :many_to_many} = relationship} ->
            get(route,
              to: AshJsonApi.Controllers.GetManyToMany,
              init_opts: [resource: resource, relationship: relationship]
            )
        end
      end
    end
  end
end
