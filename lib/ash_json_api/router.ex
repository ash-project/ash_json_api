defmodule AshJsonApi.Router do
  @moduledoc """
  Use this module to create a router for your AshJsonApi.

  To use this, create a module and do the following:

  ```elixir
  defmodule YourRouter do
    use AshJsonApi.Router,
      domains: [YourDomain, YourOtherDomain],
      # these next two are optional, only add them if you want those endpoints
      open_api: "/open_api",
      json_schema: "/json_schema"
  end
  ```

  Then in your Phoenix router or plug pipeline, forward to this plug.
  In phoenix, that looks like this:

  ```elixir
      forward "/api", YourRouter
  ```
  """
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      require Ash.Domain.Info
      use Plug.Router
      require Ash
      domains = List.wrap(opts[:domain] || opts[:domains])

      plug(:match)

      plug(Plug.Parsers,
        parsers: [:json],
        pass: ["application/vnd.api+json"],
        json_decoder: Jason
      )

      plug(:dispatch)

      if domains == [] do
        raise "At least one domain option must be provided"
      end

      for domain <- domains do
        prefix = AshJsonApi.Domain.Info.prefix(domain)
        resources = Ash.Domain.Info.resources(domain)

        resources
        |> Enum.filter(&AshJsonApi.Resource.Info.type(&1))
        |> Enum.each(fn resource ->
          for %{
                route: route,
                action: action_name,
                controller: controller,
                method: method,
                action_type: action_type,
                relationship: relationship_name
              } = route_struct <-
                AshJsonApi.Router.routes(resource) do
            opts =
              [
                relationship: Ash.Resource.Info.public_relationship(resource, relationship_name),
                action: Ash.Resource.Info.action(resource, action_name),
                resource: resource,
                domain: domain,
                prefix: prefix,
                route: route_struct
              ]
              |> Enum.reject(fn {_k, v} -> is_nil(v) end)

            match(route, via: method, to: controller, init_opts: opts)
          end
        end)
      end

      schema_domains = Enum.filter(domains, &AshJsonApi.Domain.Info.serve_schema?(&1))

      unless Enum.empty?(schema_domains) do
        match("/schema",
          via: :get,
          to: AshJsonApi.Controllers.Schema,
          init_opts: [domains: domains]
        )

        match("/schema.json",
          via: :get,
          to: AshJsonApi.Controllers.Schema,
          init_opts: [domains: domains]
        )
      end

      open_api_opts = AshJsonApi.Router.open_api_opts(opts)

      case Code.ensure_loaded?(OpenApiSpex) && opts[:open_api] do
        falsy when falsy in [nil, false] ->
          :ok

        true ->
          match("/open_api",
            via: :get,
            to: AshJsonApi.Controllers.OpenApi,
            init_opts: open_api_opts
          )

        routes when is_list(routes) ->
          for route <- routes do
            match(route, via: :get, to: AshJsonApi.Controllers.OpenApi, init_opts: open_api_opts)
          end

        route ->
          match(route, via: :get, to: AshJsonApi.Controllers.OpenApi, init_opts: open_api_opts)
      end

      case opts[:json_schema] do
        nil ->
          :ok

        true ->
          match("/json_schema", via: :get, to: AshJsonApi.Controllers.Schema, init_opts: opts)

        routes when is_list(routes) ->
          for route <- routes do
            match(route, via: :get, to: AshJsonApi.Controllers.Schema, init_opts: opts)
          end

        route ->
          match(route, via: :get, to: AshJsonApi.Controllers.Schema, init_opts: opts)
      end

      match(_, to: AshJsonApi.Controllers.NoRouteFound)
    end
  end

  def open_api_opts(opts) do
    opts
    |> Keyword.put(:modify, Keyword.get(opts, :modify_open_api))
    |> Keyword.delete(:modify_open_api)
  end

  @doc false
  def routes(resource) do
    resource
    |> AshJsonApi.Resource.Info.routes()
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
