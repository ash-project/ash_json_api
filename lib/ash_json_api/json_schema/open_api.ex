if Code.ensure_loaded?(OpenApiSpex) do
  defmodule AshJsonApi.OpenApi do
    @moduledoc """
    Provides functions for generating schemas and operations for OpenApi definitions.

    Add `open_api_spex` to your `mix.exs` deps for the required struct definitions.

    ## Example

        defmodule MyApp.OpenApi do
          alias OpenApiSpex.{OpenApi, Info, Server, Components}

          def spec do
            %OpenApi{
              info: %Info{
                title: "MyApp JSON API",
                version: "1.1"
              },
              servers: [
                Server.from_endpoint(MyAppWeb.Endpoint)
              ],
              paths: AshJsonApi.OpenApi.paths(MyApp.Api),
              tags: AshJsonApi.OpenApi.tags(MyApp.Api),
              components: %Components{
                responses: AshJsonApi.OpenApi.responses(),
                schemas: AshJsonApi.OpenApi.schemas(MyApp.Api)
              }
            }
          end
        end
    """
    alias Ash.Query.Aggregate
    alias AshJsonApi.Resource.Route
    alias Ash.Resource.{Actions, Relationships}

    alias OpenApiSpex.{
      MediaType,
      Operation,
      Parameter,
      PathItem,
      Paths,
      Reference,
      RequestBody,
      Response,
      Schema,
      Tag
    }

    @dialyzer {:nowarn_function, {:action_description, 2}}
    @dialyzer {:nowarn_function, {:relationship_resource_identifiers, 1}}
    @dialyzer {:nowarn_function, {:resource_object_schema, 1}}

    @doc """
    Common responses to include in the API Spec.
    """
    @spec responses() :: OpenApiSpex.Components.responses_map()
    def responses do
      %{
        "errors" => %Response{
          description: "General Error",
          content: %{
            "application/vnd.api+json" => %MediaType{
              schema: %Reference{"$ref": "#/components/schemas/errors"}
            }
          }
        }
      }
    end

    @doc """
    Resource schemas to include in the API spec.
    """
    @spec schemas(api :: module | [module]) :: %{String.t() => Schema.t()}
    def schemas(apis) when is_list(apis) do
      apis
      |> Enum.reduce(base_definitions(), fn api, definitions ->
        api
        |> resources
        |> Enum.map(&{AshJsonApi.Resource.Info.type(&1), resource_object_schema(&1)})
        |> Enum.into(definitions)
      end)
    end

    def schemas(api) do
      api
      |> resources
      |> Enum.map(&{AshJsonApi.Resource.Info.type(&1), resource_object_schema(&1)})
      |> Enum.into(base_definitions())
    end

    @spec base_definitions() :: %{String.t() => Schema.t()}
    defp base_definitions do
      %{
        "links" => %Schema{
          type: :object,
          additionalProperties: %Reference{"$ref": "#/components/schemas/link"}
        },
        "link" => %Schema{
          description:
            "A link MUST be represented as either: a string containing the link's URL or a link object.",
          type: :string
        },
        "errors" => %Schema{
          type: :array,
          items: %Reference{
            "$ref": "#/components/schemas/error"
          },
          uniqueItems: true
        },
        "error" => %Schema{
          type: :object,
          properties: %{
            id: %Schema{
              description: "A unique identifier for this particular occurrence of the problem.",
              type: :string
            },
            links: %Reference{
              "$ref": "#/components/schemas/links"
            },
            status: %Schema{
              description:
                "The HTTP status code applicable to this problem, expressed as a string value.",
              type: :string
            },
            code: %Schema{
              description: "An application-specific error code, expressed as a string value.",
              type: :string
            },
            title: %Schema{
              description:
                "A short, human-readable summary of the problem. It SHOULD NOT change from occurrence to occurrence of the problem, except for purposes of localization.",
              type: :string
            },
            detail: %Schema{
              description:
                "A human-readable explanation specific to this occurrence of the problem.",
              type: :string
            },
            source: %Schema{
              type: :object,
              properties: %{
                pointer: %Schema{
                  description:
                    "A JSON Pointer [RFC6901] to the associated entity in the request document [e.g. \"/data\" for a primary data object, or \"/data/attributes/title\" for a specific attribute].",
                  type: :string
                },
                parameter: %Schema{
                  description: "A string indicating which query parameter caused the error.",
                  type: :string
                }
              }
            }
            # "meta" => %{
            #   "$ref" => "#/definitions/meta"
            # }
          },
          additionalProperties: false
        }
      }
    end

    defp resources(api) do
      api
      |> Ash.Api.Info.resources()
      |> Enum.filter(&AshJsonApi.Resource.Info.type(&1))
    end

    @spec resource_object_schema(resource :: Ash.Resource.t()) :: Schema.t()
    defp resource_object_schema(resource) do
      %Schema{
        description:
          "A \"Resource object\" representing a #{AshJsonApi.Resource.Info.type(resource)}",
        type: :object,
        required: [:type, :id],
        properties: %{
          type: %Schema{type: :string},
          id: %{type: :string},
          attributes: attributes(resource),
          relationships: relationships(resource)
          # "meta" => %{
          #   "$ref" => "#/definitions/meta"
          # }
        },
        additionalProperties: false
      }
    end

    @spec attributes(resource :: Ash.Resource.t()) :: Schema.t()
    defp attributes(resource) do
      %Schema{
        description: "An attributes object for a #{AshJsonApi.Resource.Info.type(resource)}",
        type: :object,
        properties: resource_attributes(resource),
        additionalProperties: false,
        required: required_attributes(resource)
      }
    end

    @spec resource_attributes(resource :: module) :: %{atom => Schema.t()}
    defp resource_attributes(resource) do
      resource
      |> Ash.Resource.Info.public_attributes()
      |> Enum.reject(&AshJsonApi.Resource.only_primary_key?(resource, &1.name))
      |> Map.new(fn attr ->
        {attr.name, resource_attribute_type(attr)}
      end)
    end

    @spec resource_attribute_type(Ash.Resource.Attribute.t() | Ash.Resource.Actions.Argument.t()) ::
            Schema.t()
    defp resource_attribute_type(%{type: Ash.Type.String}) do
      %Schema{type: :string}
    end

    defp resource_attribute_type(%{type: Ash.Type.Boolean}) do
      %Schema{type: :boolean}
    end

    defp resource_attribute_type(%{type: Ash.Type.Integer}) do
      %Schema{type: :integer}
    end

    defp resource_attribute_type(%{type: Ash.Type.UtcDatetime}) do
      %Schema{
        type: :string,
        format: "date-time"
      }
    end

    defp resource_attribute_type(%{type: Ash.Type.UUID}) do
      %Schema{
        type: :string,
        format: "uuid"
      }
    end

    defp resource_attribute_type(%{type: {:array, type}} = attr) do
      %Schema{
        type: :array,
        items:
          resource_attribute_type(%{
            attr
            | type: type,
              constraints: attr.constraints[:items] || []
          })
      }
    end

    defp resource_attribute_type(%{type: type} = attr) do
      if :erlang.function_exported(type, :json_schema, 1) do
        if Map.get(attr, :constraints) do
          type.json_schema(attr.constraints)
        else
          type.json_schema([])
        end
      else
        %Schema{
          type: :object,
          additionalProperties: true
        }
      end
    end

    @spec required_attributes(resource :: module) :: nil | [:atom]
    defp required_attributes(resource) do
      resource
      |> Ash.Resource.Info.public_attributes()
      |> Enum.reject(&(&1.allow_nil? || AshJsonApi.Resource.only_primary_key?(resource, &1.name)))
      |> Enum.map(& &1.name)
      |> case do
        [] -> nil
        attributes -> attributes
      end
    end

    @spec relationships(resource :: Ash.Resource.t()) :: Schema.t()
    defp relationships(resource) do
      %Schema{
        description: "A relationships object for a #{AshJsonApi.Resource.Info.type(resource)}",
        type: :object,
        properties: resource_relationships(resource),
        additionalProperties: false
      }
    end

    @spec resource_relationships(resource :: module) :: %{atom => Schema.t()}
    defp resource_relationships(resource) do
      resource
      |> Ash.Resource.Info.public_relationships()
      |> Enum.filter(fn relationship ->
        AshJsonApi.Resource.Info.type(relationship)
      end)
      |> Map.new(fn rel ->
        data = resource_relationship_field_data(resource, rel)
        links = resource_relationship_link_data(resource, rel)

        object =
          if links do
            %Schema{properties: %{data: data, links: links}}
          else
            %Schema{properties: %{data: data}}
          end

        {rel.name, object}
      end)
    end

    defp resource_relationship_link_data(_resource, _rel) do
      nil
    end

    @spec resource_relationship_field_data(
            resource :: module,
            Relationships.relationship()
          ) :: Schema.t()
    defp resource_relationship_field_data(_resource, %{
           type: {:array, _},
           name: name
         }) do
      %Schema{
        description: "Identifiers for #{name}",
        type: :object,
        nullable: true,
        required: [:type, :id],
        additionalProperties: false,
        properties: %{
          type: %Schema{type: :string},
          id: %Schema{type: :string},
          meta: %Schema{
            type: :object,
            additionalProperties: true
          }
        }
      }
    end

    defp resource_relationship_field_data(_resource, %{
           name: name
         }) do
      %Schema{
        description: "An array of inputs for #{name}",
        type: :array,
        items: %{
          description: "Resource identifiers for #{name}",
          type: :object,
          required: [:type, :id],
          properties: %{
            type: %Schema{type: :string},
            id: %Schema{type: :string},
            meta: %Schema{
              type: :object,
              additionalProperties: true
            }
          }
        },
        uniqueItems: true
      }
    end

    @doc """
    Tags based on resource names to include in the API spec
    """
    @spec tags(api :: module | [module]) :: [Tag.t()]
    def tags(apis) when is_list(apis) do
      Enum.flat_map(apis, &tags/1)
    end

    def tags(api) do
      api
      |> resources()
      |> Enum.map(fn resource ->
        name = AshJsonApi.Resource.Info.type(resource)

        %Tag{
          name: to_string(name),
          description: "Operations on the #{name} resource."
        }
      end)
    end

    @doc """
    Paths (routes) from the API.
    """
    @spec paths(api :: module | [module]) :: Paths.t()
    def paths(apis) when is_list(apis) do
      apis
      |> Enum.map(&paths/1)
      |> Enum.reduce(&Map.merge/2)
    end

    def paths(api) do
      api
      |> resources()
      |> Enum.flat_map(fn resource ->
        resource
        |> AshJsonApi.Resource.Info.routes()
        |> Enum.map(&route_operation(&1, api, resource))
      end)
      |> Enum.group_by(fn {path, _route_op} -> path end, fn {_path, route_op} -> route_op end)
      |> Map.new(fn {path, route_ops} -> {path, struct!(PathItem, route_ops)} end)
    end

    @spec route_operation(Route.t(), api :: module, resource :: module) ::
            {Paths.path(), {verb :: atom, Operation.t()}}
    defp route_operation(route, api, resource) do
      {path, path_params} = AshJsonApi.JsonSchema.route_href(route, api)
      operation = operation(route, resource, path_params)
      {path, {route.method, operation}}
    end

    @spec operation(Route.t(), resource :: module, path_params :: [String.t()]) ::
            Operation.t()
    defp operation(route, resource, path_params) do
      unless path_params == [] or path_params == ["id"] do
        raise "Haven't figured out more complex route parameters yet."
      end

      action = Ash.Resource.Info.action(resource, route.action)

      %Operation{
        description: action_description(action, resource),
        tags: [to_string(AshJsonApi.Resource.Info.type(resource))],
        parameters: path_parameters(path_params, action) ++ query_parameters(route, resource),
        responses: %{
          :default => %Reference{
            "$ref": "#/components/responses/errors"
          },
          200 => response_body(route, resource)
        },
        requestBody: request_body(route, resource)
      }
    end

    defp action_description(action, resource) do
      action.description ||
        "#{action.name} operation on #{AshJsonApi.Resource.Info.type(resource)} resource"
    end

    @spec path_parameters(path_params :: [String.t()], action :: Actions.action()) ::
            [Parameter.t()]
    defp path_parameters(path_params, action) do
      Enum.map(path_params, fn param ->
        description =
          action.arguments
          |> Enum.find(&(to_string(&1.name) == param))
          |> case do
            %{description: description} when is_binary(description) -> description
            _ -> nil
          end

        %Parameter{
          name: param,
          description: description,
          in: :path,
          required: true,
          schema: %Schema{type: :string}
        }
      end)
    end

    @spec query_parameters(
            Route.t(),
            resource :: module
          ) :: [Parameter.t()]
    defp query_parameters(%{type: :index} = route, resource) do
      [
        filter_parameter(resource),
        sort_parameter(resource),
        page_parameter(),
        include_parameter(),
        fields_parameter(resource)
      ] ++
        read_argument_parameters(route, resource)
    end

    defp query_parameters(%{type: type}, _resource)
         when type in [:post_to_relationship, :patch_relationship, :delete_from_relationship] do
      []
    end

    defp query_parameters(%{type: type} = route, resource) when type in [:get, :related] do
      [include_parameter(), fields_parameter(resource)] ++
        read_argument_parameters(route, resource)
    end

    defp query_parameters(_route, resource) do
      [include_parameter(), fields_parameter(resource)]
    end

    @spec filter_parameter(resource :: module) :: Parameter.t()
    defp filter_parameter(resource) do
      %Parameter{
        name: :filter,
        in: :query,
        description:
          "Filters the query to results with attributes matching the given filter object",
        required: false,
        style: :deepObject,
        schema: filter_schema(resource)
      }
    end

    @spec sort_parameter(resource :: module) :: Parameter.t()
    defp sort_parameter(resource) do
      sorts =
        resource
        |> Ash.Resource.Info.public_attributes()
        |> Enum.flat_map(fn attr -> [to_string(attr.name), "-#{attr.name}"] end)

      %Parameter{
        name: :sort,
        in: :query,
        description: "Sort order to apply to the results",
        required: false,
        style: :form,
        explode: false,
        schema: %Schema{
          type: :array,
          items: %Schema{
            type: :string,
            enum: sorts
          }
        }
      }
    end

    @spec page_parameter() :: Parameter.t()
    defp page_parameter do
      %Parameter{
        name: :page,
        in: :query,
        description: "Paginates the response with the limit and offset",
        required: false,
        style: :deepObject,
        schema: %Schema{
          type: :object,
          properties: %{
            limit: %Schema{type: :integer, minimum: 1},
            offset: %Schema{type: :integer, minimum: 0}
          }
        }
      }
    end

    @spec include_parameter() :: Parameter.t()
    defp include_parameter do
      %Parameter{
        name: :include,
        in: :query,
        required: false,
        description: "Relationship paths to include in the response",
        style: :form,
        explode: false,
        schema: %Schema{
          type: :array,
          items: %Schema{
            type: :string,
            pattern: ~r/^[a-zA-Z_]\w*(\.[a-zA-Z_]\w*)*$/
          }
        }
      }
    end

    @spec fields_parameter(resource :: module) :: Parameter.t()
    defp fields_parameter(resource) do
      type = AshJsonApi.Resource.Info.type(resource)

      %Parameter{
        name: :fields,
        in: :query,
        description: "Limits the response fields to only those listed for each type",
        required: false,
        style: :deepObject,
        schema: %Schema{
          type: :object,
          additionalProperties: true,
          properties: %{
            # There is a static set of types (one per resource)
            # so this is safe.
            #
            # sobelow_skip ["DOS.StringToAtom"]
            String.to_atom(type) => %Schema{
              description: "Comma separated field names for #{type}",
              type: :string,
              example:
                Ash.Resource.Info.public_attributes(resource)
                |> Enum.map_join(",", & &1.name)
            }
          }
        }
      }
    end

    @spec read_argument_parameters(Route.t(), resource :: module) :: [Parameter.t()]
    defp read_argument_parameters(route, resource) do
      action = Ash.Resource.Info.action(resource, route.action, :read)

      action.arguments
      |> Enum.reject(& &1.private?)
      |> Enum.map(fn argument ->
        schema = resource_attribute_type(argument)

        %Parameter{
          name: argument.name,
          in: :query,
          description: argument.description || to_string(argument.name),
          required: !argument.allow_nil?,
          style:
            case schema.type do
              :object -> :deepObject
              _ -> :form
            end,
          schema: schema
        }
      end)
    end

    @spec filter_schema(resource :: module) :: Schema.t()
    defp filter_schema(resource) do
      props =
        resource
        |> Ash.Resource.Info.public_attributes()
        |> Map.new(fn attr ->
          {attr.name, attribute_filter_schema(attr.type)}
        end)

      props =
        resource
        |> Ash.Resource.Info.public_relationships()
        |> Enum.map(fn rel ->
          {rel.name, relationship_filter_schema(rel)}
        end)
        |> Enum.into(props)

      props =
        resource
        |> Ash.Resource.Info.public_aggregates()
        |> Enum.map(fn agg ->
          {:ok, type} = Aggregate.kind_to_type(agg.kind, nil)
          {agg.name, attribute_filter_schema(type)}
        end)
        |> Enum.into(props)

      %Schema{
        type: :object,
        properties: props
      }
    end

    @spec relationship_filter_schema(relationship :: Relationships.relationship()) :: Schema.t()
    defp relationship_filter_schema(_rel) do
      %Schema{type: :string}
    end

    @spec attribute_filter_schema(type :: module) :: Schema.t()
    defp attribute_filter_schema(type) do
      if Ash.Type.embedded_type?(type) do
        %Schema{
          type: :object,
          additionalProperties: true
        }
      else
        case type do
          Ash.Type.UUID ->
            %Schema{
              type: :string,
              format: :uuid
            }

          Ash.Type.String ->
            %Schema{type: :string}

          Ash.Type.Boolean ->
            %Schema{type: :boolean}

          Ash.Type.Integer ->
            %Schema{type: :integer}

          Ash.Type.UtcDateTime ->
            %Schema{type: :string, format: :"date-time"}

          {:array, _type} ->
            %Schema{
              type: :object,
              additionalProperties: true
            }

          _ ->
            %Schema{
              type: :object,
              additionalProperties: true
            }
        end
      end
    end

    @spec request_body(Route.t(), resource :: module) :: nil | RequestBody.t()
    defp request_body(%{method: method}, _resource)
         when method in [:get, :delete] do
      nil
    end

    defp request_body(route, resource) do
      body_schema = request_body_schema(route, resource)

      body_required =
        body_schema.properties.data.properties.attributes.required != [] ||
          body_schema.properties.data.properties.relationships.required != []

      %RequestBody{
        description:
          "Request body for #{route.action} operation on #{AshJsonApi.Resource.Info.type(resource)} resource",
        required: body_required,
        content: %{
          "application/vnd.api+json" => %MediaType{schema: body_schema}
        }
      }
    end

    @spec request_body_schema(Route.t(), resource :: module) :: Schema.t()
    defp request_body_schema(
           %{
             type: :post,
             action: action,
             action_type: action_type,
             relationship_arguments: relationship_arguments
           },
           resource
         ) do
      action = Ash.Resource.Info.action(resource, action, action_type)

      non_relationship_arguments =
        Enum.reject(
          action.arguments,
          &has_relationship_argument?(relationship_arguments, &1.name)
        )

      %Schema{
        type: :object,
        required: [:data],
        additionalProperties: false,
        properties: %{
          data: %Schema{
            type: :object,
            additionalProperties: false,
            properties: %{
              type: %Schema{
                enum: [AshJsonApi.Resource.Info.type(resource)]
              },
              attributes: %Schema{
                type: :object,
                additionalProperties: false,
                properties: write_attributes(resource, non_relationship_arguments, action.accept),
                required:
                  required_write_attributes(resource, non_relationship_arguments, action.accept)
              },
              relationships: %Schema{
                type: :object,
                additionalProperties: false,
                properties: write_relationships(resource, relationship_arguments, action),
                required:
                  required_relationship_attributes(resource, relationship_arguments, action)
              }
            }
          }
        }
      }
    end

    defp request_body_schema(
           %{
             type: :patch,
             action: action,
             action_type: action_type,
             relationship_arguments: relationship_arguments
           },
           resource
         ) do
      action = Ash.Resource.Info.action(resource, action, action_type)

      non_relationship_arguments =
        Enum.reject(
          action.arguments,
          &has_relationship_argument?(relationship_arguments, &1.name)
        )

      %Schema{
        type: :object,
        required: [:data],
        additionalProperties: false,
        properties: %{
          data: %Schema{
            type: :object,
            additionalProperties: false,
            required: [:id],
            properties: %{
              id: %Schema{
                type: :string
              },
              type: %Schema{
                enum: [AshJsonApi.Resource.Info.type(resource)]
              },
              attributes: %Schema{
                type: :object,
                additionalProperties: false,
                properties: write_attributes(resource, non_relationship_arguments, action.accept),
                required:
                  non_relationship_arguments
                  |> Enum.reject(& &1.allow_nil?)
                  |> Enum.map(&to_string(&1.name))
              },
              relationships: %Schema{
                type: :object,
                additionalProperties: false,
                properties: write_relationships(resource, relationship_arguments, action),
                required:
                  required_relationship_attributes(resource, relationship_arguments, action)
              }
            }
          }
        }
      }
    end

    defp request_body_schema(
           %{type: type, relationship: relationship},
           resource
         )
         when type in [:post_to_relationship, :patch_relationship, :delete_from_relationship] do
      resource
      |> Ash.Resource.Info.public_relationship(relationship)
      |> relationship_resource_identifiers()
    end

    @spec required_write_attributes(
            resource :: module,
            [Ash.Resource.Actions.Argument.t()],
            accept :: [atom()]
          ) :: [atom()]
    defp required_write_attributes(resource, arguments, accept) do
      attributes =
        resource
        |> Ash.Resource.Info.public_attributes()
        |> Enum.filter(&((is_nil(accept) || &1.name in accept) && &1.writable?))
        |> Enum.reject(&(&1.allow_nil? || &1.default || &1.generated?))
        |> Enum.map(& &1.name)

      arguments =
        arguments
        |> Enum.reject(& &1.allow_nil?)
        |> Enum.map(& &1.name)

      attributes ++ arguments
    end

    @spec write_attributes(
            resource :: module,
            [Ash.Resource.Actions.Argument.t()],
            accept :: [atom()]
          ) :: %{atom => Schema.t()}
    defp write_attributes(resource, arguments, accept) do
      attributes =
        resource
        |> Ash.Resource.Info.public_attributes()
        |> Enum.filter(&((is_nil(accept) || &1.name in accept) && &1.writable?))
        |> Map.new(fn attribute ->
          {attribute.name, resource_attribute_type(attribute)}
        end)

      Enum.reduce(arguments, attributes, fn argument, attributes ->
        Map.put(attributes, argument.name, resource_attribute_type(argument))
      end)
    end

    @spec required_relationship_attributes(
            resource :: module,
            [Actions.Argument.t()],
            Actions.action()
          ) :: [atom()]
    defp required_relationship_attributes(_resource, relationship_arguments, action) do
      action.arguments
      |> Enum.filter(&has_relationship_argument?(relationship_arguments, &1.name))
      |> Enum.reject(& &1.allow_nil?)
      |> Enum.map(& &1.name)
    end

    @spec write_relationships(resource :: module, [Actions.Argument.t()], Actions.action()) ::
            %{atom() => Schema.t()}
    defp write_relationships(resource, relationship_arguments, action) do
      action.arguments
      |> Enum.filter(&has_relationship_argument?(relationship_arguments, &1.name))
      |> Map.new(fn argument ->
        data = resource_relationship_field_data(resource, argument)

        schema = %Schema{
          type: :object,
          properties: %{
            data: data,
            links: %Schema{type: :object, additionalProperties: true}
          }
        }

        {argument.name, schema}
      end)
    end

    @spec has_relationship_argument?(relationship_arguments :: list, name :: atom) :: boolean()
    defp has_relationship_argument?(relationship_arguments, name) do
      Enum.any?(relationship_arguments, fn
        {:id, ^name} -> true
        ^name -> true
        _ -> false
      end)
    end

    @spec response_body(Route.t(), resource :: module) :: Response.t()
    defp response_body(%{method: :delete}, _resource) do
      %Response{
        description: "Deleted successfully"
      }
    end

    defp response_body(route, resource) do
      %Response{
        description: "Success",
        content: %{
          "application/vnd.api+json" => %MediaType{
            schema: response_schema(route, resource)
          }
        }
      }
    end

    @spec response_schema(Route.t(), resource :: module) :: Schema.t()
    defp response_schema(route, resource) do
      case route.type do
        :index ->
          %Schema{
            type: :object,
            properties: %{
              data: %Schema{
                description:
                  "An array of resource objects representing a #{AshJsonApi.Resource.Info.type(resource)}",
                type: :array,
                items: %Reference{
                  "$ref": "#/components/schemas/#{AshJsonApi.Resource.Info.type(resource)}"
                },
                uniqueItems: true
              }
            }
          }

        :delete ->
          nil

        type
        when type in [:post_to_relationship, :patch_relationship, :delete_from_relationship] ->
          resource
          |> Ash.Resource.Info.public_relationship(route.relationship)
          |> relationship_resource_identifiers()

        _ ->
          %Schema{
            properties: %{
              data: %Reference{
                "$ref": "#/components/schemas/#{AshJsonApi.Resource.Info.type(resource)}"
              }
            }
          }
      end
    end

    @spec relationship_resource_identifiers(relationship :: Relationships.relationship()) ::
            Schema.t()
    defp relationship_resource_identifiers(relationship) do
      %Schema{
        type: :object,
        required: [:data],
        additionalProperties: false,
        properties: %{
          data: %{
            type: :array,
            items: %{
              type: :object,
              required: [:id, :type],
              additionalProperties: false,
              properties: %{
                id: %Schema{
                  type: :string
                },
                type: %Schema{
                  enum: [AshJsonApi.Resource.Info.type(relationship.destination)]
                },
                meta: %Schema{
                  type: :object,
                  additionalProperties: true
                }
              }
            }
          }
        }
      }
    end
  end
end
