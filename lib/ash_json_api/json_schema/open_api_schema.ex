defmodule AshJsonApi.OpenApiSchema do
  @moduledoc false
  alias AshJsonApi.JsonSchema

  @doc "See https://swagger.io/specification/#openapi-object"
  def generate(api) do
    resources =
      api
      |> Ash.Api.Info.resources()
      |> Enum.filter(&(AshJsonApi.Resource in Spark.extensions(&1)))

    paths =
      Enum.flat_map(resources, fn resource ->
        resource
        |> AshJsonApi.Resource.Info.routes()
        |> Enum.map(&open_api_path(&1, api, resource))
      end)
      |> Enum.group_by(fn {path, _path_item} -> path end, fn {_path, path_item} -> path_item end)
      |> Map.new(fn {path, path_items} -> {path, Map.new(path_items)} end)

    definitions =
      Enum.reduce(resources, JsonSchema.base_definitions(definitions_path: "#/components/schemas"), fn resource, acc ->
        Map.put(acc, AshJsonApi.Resource.Info.type(resource), JsonSchema.resource_object_schema(resource))
      end)

    info = openapi_info(api)

    common_responses = %{
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

    %{
      # Note: Using version 3.0.3 as some tooling such as SwaggerUI hasn't updated to 3.1.0 yet.
      "openapi" => "3.0.3",
      "info" => info,
      "paths" => paths,
      "components" => %{
        "responses" => common_responses,
        "schemas" => definitions
      },
      "servers" => [],
      "security" => [],
      "tags" => []
      # "externalDocs" => nil,
      # "extensions" => nil
    }
  end

  @doc "See https://swagger.io/specification/#info-object"
  def openapi_info(_api) do
    %{
      "title" => "title pending",
      "description" => "description pending",
      "version" => "api document version pending"
    }
  end

  def open_api_path(%{method: :get} = route, api, resource) do
    method = "get"
    {href, path_params} = JsonSchema.route_href(route, api)

    operation = %{
      "parameters" =>
        path_parameters(path_params) ++
          query_parameters(route, api, resource),
      "responses" => %{
        "default" => %{
          "$ref" => "#/components/responses/errors"
        },
        "200" => %{
          "description" => "Success",
          "content" => %{
            "application/vnd.api+json" => %{
              "schema" => target_schema(route, api, resource)
            }
          }
        }
      }
    }

    {href, {method, operation}}
  end

  def open_api_path(%{method: :delete} = route, api, _resource) do
    method = "delete"
    {href, path_params} = JsonSchema.route_href(route, api)

    operation = %{
      "parameters" => path_parameters(path_params),
      "responses" => %{
        "default" => %{
          "$ref" => "#/components/responses/errors"
        },
        "200" => %{
          "description" => "Success",
          "content" => %{
            "application/vnd.api+json" => %{
              "description" => "The resource was deleted successfully."
            }
          }
        }
      }
    }

    {href, %{method => operation}}
  end

  def open_api_path(route, api, resource) do
    method = route.method |> to_string()
    {href, path_params} = JsonSchema.route_href(route, api)

    unless path_params == [] or path_params == ["id"] do
      raise "Haven't figured out more complex route parameters yet."
    end

    body_schema = JsonSchema.route_in_schema(route, api, resource)

    body_required =
      body_schema["properties"]["data"]["properties"]["attributes"]["required"] != [] ||
        body_schema["properties"]["data"]["properties"]["relationships"]["required"] != []

    operation = %{
      "parameters" =>
        path_parameters(path_params) ++
          query_parameters(route, api, resource),
      "requestBody" => %{
        "description" => "Body description pending",
        "required" => body_required,
        "content" => %{
          "application/vnd.api+json" => %{"schema" => body_schema}
        }
      },
      "responses" => %{
        "default" => %{
          "$ref" => "#/components/responses/errors"
        },
        "200" => %{
          "description" => "Success",
          "content" => %{
            "application/vnd.api+json" => %{
              "schema" => target_schema(route, api, resource)
            }
          }
        }
      }
    }

    {href, {method, operation}}
  end

  def path_parameters(path_params) do
    Enum.map(path_params, fn param ->
      %{
        "name" => param,
        "in" => "path",
        "description" => "param description pending",
        "required" => true,
        "schema" => %{"type" => "string"}
      }
    end)
  end

  def query_parameters(route, api, resource) do
    case JsonSchema.query_param_properties(route, api, resource) do
      nil ->
        []

      {query_param_properties, _query_param_string, required} ->
        Enum.map(query_param_properties, fn {name, schema} ->
          %{
            "name" => name,
            "in" => "query",
            "description" => "query param description pending",
            "required" => name in required,
            "schema" => schema
          }
        end)
    end
  end

  defp target_schema(route, _api, resource) do
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
