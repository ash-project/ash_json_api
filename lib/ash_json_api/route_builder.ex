# defmodule AshJsonApi.RouteBuilder do
#   defmacro build_routes(resource) do
#     quote bind_quoted: [resource: resource] do
#       for %{
#             route: route,
#             action: action_name,
#             controller: controller,
#             method: method,
#             relationship: relationship_name
#           } <-
#             AshJsonApi.routes(resource) do
#         opts =
#           [
#             relationship: Ash.relationship(resource, relationship_name),
#             action: Ash.action(resource, action_name),
#             resource: resource
#           ]
#           |> Enum.reject(fn {_k, v} -> is_nil(v) end)

#         match(route, via: method, to: controller, init_opts: opts)
#       end
#     end
#   end
# end
