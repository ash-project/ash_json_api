defmodule AshJsonApi.OpenApiSchema do
  @moduledoc false
  alias AshJsonApi.JsonSchema

  @doc "See https://swagger.io/specification/#openapi-object"
  def generate(api) do
    resources = resources(api)

    %{
      # Note: Using version 3.0.3 as some tooling such as SwaggerUI hasn't updated to 3.1.0 yet.
      "openapi" => "3.0.3",
      "info" => info(api),
      "paths" => paths(api, resources),
      "components" => %{
        "responses" => responses(),
        "schemas" => schemas(resources)
      },
      "servers" => [],
      "security" => [],
      "tags" => tags(resources)
      # "externalDocs" => nil,
      # "extensions" => nil
    }
  end

  @doc "See https://swagger.io/specification/#info-object"
  def info(api) do
    %{
      "title" => String.capitalize("#{Ash.Api.Info.short_name(api)}") <> " API",
      "description" => description(api),
      "version" => document_version()
    }
  end

  def description(api) do
    # TODO: Get this value from a DSL attribute
    case Code.fetch_docs(api) do
      {:docs_v1, _, :elixir, "text/markdown", %{"en" => description}, %{}, _} ->
        String.trim(description)

      _ ->
        ""
    end
  end

  def document_version do
    # TODO: Get this value from a DSL attribute
    "1.0"
  end

  def resources(api) do
    api
    |> Ash.Api.Info.resources()
    |> Enum.filter(&(AshJsonApi.Resource in Spark.extensions(&1)))
  end

  def responses do
    %{
      "errors" => %{
        "description" => "General Error",
        "content" => %{
          "application/vnd.api+json" => %{
            "schema" => %{
              "$ref" => "#/components/schemas/errors"
            }
          }
        }
      }
    }
  end

  def schemas(resources) do
    resources
    |> Enum.map(&{AshJsonApi.Resource.Info.type(&1), JsonSchema.resource_object_schema(&1)})
    |> Enum.into(JsonSchema.base_definitions(definitions_path: "#/components/schemas"))
  end

  # See: https://swagger.io/specification/#tag-object
  def tags(resources) do
    resources
    |> Enum.map(fn resource ->
      name = Ash.Resource.Info.short_name(resource)

      %{
        "name" => to_string(name),
        "description" => "Operations on the **#{name}** resource."
      }
    end)
  end

  # See: https://swagger.io/specification/#paths-object
  def paths(api, resources) do
    Enum.flat_map(resources, fn resource ->
      resource
      |> AshJsonApi.Resource.Info.routes()
      |> Enum.map(&path_item(&1, api, resource))
    end)
    |> Enum.group_by(fn {path, _path_item} -> path end, fn {_path, path_item} -> path_item end)
    |> Map.new(fn {path, path_items} -> {path, Map.new(path_items)} end)
  end

  # See: https://swagger.io/specification/#path-item-object
  def path_item(route, api, resource) do
    method = route.method |> to_string()
    {href, path_params} = JsonSchema.route_href(route, api)
    operation = operation(route, api, resource, path_params)
    {href, {method, operation}}
  end

  # see: https://swagger.io/specification/#operation-object
  def operation(route, api, resource, path_params) do
    unless path_params == [] or path_params == ["id"] do
      raise "Haven't figured out more complex route parameters yet."
    end

    action = Ash.Resource.Info.action(resource, route.action)

    %{
      "description" =>
        action.description ||
          "**#{action.name}** operation on **#{Ash.Resource.Info.short_name(resource)}** resource",
      "tags" => [to_string(Ash.Resource.Info.short_name(resource))],
      "parameters" =>
        path_parameters(route, path_params, action) ++
          query_parameters(route, api, resource, action),
      "responses" => %{
        "default" => %{
          "$ref" => "#/components/responses/errors"
        }
      }
    }
    |> add_request_body(route, api, resource)
    |> add_response_body(route, api, resource)
  end

  def path_parameters(route, path_params, action) do
    Enum.map(path_params, fn param ->
      %{
        "name" => param,
        "description" => parameter_description(route, param, action),
        "in" => "path",
        "required" => true,
        "schema" => %{"type" => "string"}
      }
    end)
  end

  def query_parameters(route, api, resource, action) do
    case JsonSchema.query_param_properties(route, api, resource) do
      nil ->
        []

      {query_param_properties, _query_param_string, required} ->
        Enum.map(query_param_properties, fn {name, schema} ->
          %{
            "name" =>
              case schema["type"] do
                # When Plug encounters a query parameter appearing multiple times, it only
                # retains the last value (https://hexdocs.pm/plug/Plug.Conn.Query.html).
                # The []-suffixed naming convention is required to create a list.
                "array" -> name <> "[]"
                _ -> name
              end,
            "in" => "query",
            "description" => parameter_description(route, name, action),
            "required" => name in required,
            "schema" => schema,
            "explode" => true,
            "style" =>
              case schema["type"] do
                "object" -> "deepObject"
                _ -> "form"
              end
          }
        end)
    end
  end

  def parameter_description(%{type: :index}, "filter", _action) do
    "Filters the query to results with attributes matching the given filter object"
  end

  def parameter_description(%{type: :index}, "page", _action) do
    "Paginates the response with the limit and offset"
  end

  def parameter_description(%{type: :index}, "sort", _action) do
    "Sort order to apply to the results"
  end

  def parameter_description(_, "include", _action) do
    "Comma separated list of relationship paths to include in the response"
  end

  def parameter_description(_route, name, action) do
    arg = Enum.find(action.arguments, fn arg -> to_string(arg.name) == name end)

    case arg do
      %{description: description} when is_binary(description) -> description
      _ -> name
    end
  end

  defp add_request_body(operation, %{method: method}, _api, _resource)
       when method in [:get, :delete] do
    operation
  end

  defp add_request_body(operation, route, api, resource) do
    body_schema = JsonSchema.route_in_schema(route, api, resource)

    body_required =
      body_schema["properties"]["data"]["properties"]["attributes"]["required"] != [] ||
        body_schema["properties"]["data"]["properties"]["relationships"]["required"] != []

    Map.put(operation, "requestBody", %{
      "description" =>
        "Request body for **#{route.action}** operation on **#{Ash.Resource.Info.short_name(resource)}** resource",
      "required" => body_required,
      "content" => %{
        "application/vnd.api+json" => %{"schema" => body_schema}
      }
    })
  end

  defp add_response_body(operation, %{method: :delete}, _api, _resource) do
    put_in(operation, ["responses", "200"], %{
      "description" => "Success",
      "content" => %{
        "application/vnd.api+json" => %{
          "description" => "Deleted successfully"
        }
      }
    })
  end

  defp add_response_body(operation, route, api, resource) do
    put_in(operation, ["responses", "200"], %{
      "description" => "Success",
      "content" => %{
        "application/vnd.api+json" => %{
          "schema" => response_body_schema(route, api, resource)
        }
      }
    })
  end

  defp response_body_schema(route, _api, resource) do
    case route.type do
      :index ->
        %{
          "properties" => %{
            "data" => %{
              "description" =>
                "An array of resource objects representing a #{AshJsonApi.Resource.Info.type(resource)}",
              "type" => "array",
              "items" => %{
                "$ref" => "#/components/schemas/#{AshJsonApi.Resource.Info.type(resource)}"
              },
              "uniqueItems" => true
            }
          }
        }

      :delete ->
        nil

      type when type in [:post_to_relationship, :patch_relationship, :delete_from_relationship] ->
        resource
        |> Ash.Resource.Info.public_relationship(route.relationship)
        |> JsonSchema.relationship_resource_identifiers()

      _ ->
        %{
          "properties" => %{
            "data" => %{
              "$ref" => "#/components/schemas/#{AshJsonApi.Resource.Info.type(resource)}"
            }
          }
        }
    end
  end
end
