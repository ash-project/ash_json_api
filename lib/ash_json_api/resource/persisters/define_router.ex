defmodule AshJsonApi.Resource.Persisters.DefineRouter do
  @moduledoc false
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  def transform(dsl) do
    routes = AshJsonApi.Resource.Info.routes(dsl)

    route_matchers =
      routes
      |> Enum.sort(fn left, right ->
        left_path = Path.split(left.route)
        right_path = Path.split(right.route)

        left_path
        |> Enum.zip(right_path)
        |> sorts_first?()
        |> case do
          :undecided ->
            Enum.count(left_path) > Enum.count(right_path)

          result ->
            result
        end
      end)
      |> Enum.map(&route_match/1)

    {:ok,
     Transformer.eval(
       dsl,
       [],
       route_matchers ++
         [
           quote do
             def json_api_match_route(_, _) do
               :error
             end
           end
         ]
     )}
  end

  # sobelow_skip ["DOS.StringToAtom"]
  def route_match(route) do
    split_route = String.split(route.route, "/", trim: true)

    args =
      Enum.map(split_route, fn
        ":" <> param ->
          {String.to_atom(param), [], Elixir}

        param ->
          param
      end)

    params =
      split_route
      |> Enum.filter(&String.starts_with?(&1, ":"))
      |> Enum.map(fn ":" <> param ->
        {param, {String.to_atom(param), [], Elixir}}
      end)

    params = {:%{}, [], params}

    quote do
      def json_api_match_route(unquote(route.method), [unquote_splicing(args)]) do
        {:ok, unquote(Macro.escape(route)), unquote(params)}
      end

      def json_api_match_route(unquote(String.upcase(to_string(route.method))), [
            unquote_splicing(args)
          ]) do
        {:ok, unquote(Macro.escape(route)), unquote(params)}
      end
    end
  end

  defp sorts_first?(zipped) do
    Enum.reduce_while(zipped, :undecided, fn {left_part, right_part}, :undecided ->
      left_param? = String.starts_with?(left_part, ":")
      right_param? = String.starts_with?(right_part, ":")

      cond do
        left_part == right_part ->
          {:cont, :undecided}

        left_param? and not right_param? ->
          {:halt, false}

        not left_param? and right_param? ->
          {:halt, true}

        true ->
          {:cont, :undecided}
      end
    end)
  end
end

# for domain <- domains do
#   prefix = AshJsonApi.Domain.Info.prefix(domain)
#   resources = Ash.Domain.Info.resources(domain)

#   resources
#   |> Enum.filter(&AshJsonApi.Resource.Info.type(&1))
#   |> Enum.each(fn resource ->
#     for %{
#           route: route,
#           action: action_name,
#           controller: controller,
#           method: method,
#           action_type: action_type,
#           relationship: relationship_name
#         } = route_struct <-
#           AshJsonApi.Router.routes(resource) do
#       relationship =
#         if route_struct.type in [
#              :patch_relationship,
#              :post_to_relationship,
#              :delete_from_relationship
#            ] do
#           relationship_name
#         else
#           Ash.Resource.Info.public_relationship(resource, relationship_name)
#         end

#       opts =
#         [
#           relationship: relationship,
#           action: Ash.Resource.Info.action(resource, action_name),
#           resource: resource,
#           domain: domain,
#           prefix: prefix,
#           route: route_struct
#         ]
#         |> Enum.reject(fn {_k, v} -> is_nil(v) end)

#       match(route, via: method, to: controller, init_opts: opts)
#     end
#   end)
# end

# schema_domains = Enum.filter(domains, &AshJsonApi.Domain.Info.serve_schema?(&1))

# unless Enum.empty?(schema_domains) do
#   match("/schema",
#     via: :get,
#     to: AshJsonApi.Controllers.Schema,
#     init_opts: [domains: domains]
#   )

#   match("/schema.json",
#     via: :get,
#     to: AshJsonApi.Controllers.Schema,
#     init_opts: [domains: domains]
#   )
# end

# open_api_opts = AshJsonApi.Router.open_api_opts(opts)

# case Code.ensure_loaded?(OpenApiSpex) && opts[:open_api] do
#   falsy when falsy in [nil, false] ->
#     :ok

#   true ->
#     match("/open_api",
#       via: :get,
#       to: AshJsonApi.Controllers.OpenApi,
#       init_opts: open_api_opts
#     )

#   routes when is_list(routes) ->
#     for route <- routes do
#       match(route, via: :get, to: AshJsonApi.Controllers.OpenApi, init_opts: open_api_opts)
#     end

#   route ->
#     match(route, via: :get, to: AshJsonApi.Controllers.OpenApi, init_opts: open_api_opts)
# end

# case opts[:json_schema] do
#   nil ->
#     :ok

#   true ->
#     match("/json_schema", via: :get, to: AshJsonApi.Controllers.Schema, init_opts: opts)

#   routes when is_list(routes) ->
#     for route <- routes do
#       match(route, via: :get, to: AshJsonApi.Controllers.Schema, init_opts: opts)
#     end

#   route ->
#     match(route, via: :get, to: AshJsonApi.Controllers.Schema, init_opts: opts)
# end

# end
# end

# def open_api_opts(opts) do
# opts
# |> Keyword.put(:modify, Keyword.get(opts, :modify_open_api))
# |> Keyword.delete(:modify_open_api)
# end

# end
