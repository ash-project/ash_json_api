defmodule AshJsonApi.JsonSchema do
  @moduledoc false
  alias Ash.Query.Aggregate

  # This JsonSchema needs to go away at some point. The only one we *really* need is the open api schema.
  # To that end, there are various places where this is more permissive than the openapi schema, using `"any"`
  # or `"object"` for example.

  def generate(domains, opts \\ []) do
    schema_id = "autogenerated_ash_json_api_schema"

    {definitions, route_schemas} =
      Enum.reduce(domains, {base_definitions(), []}, fn domain, {definitions, schemas} ->
        resources =
          domain
          |> Ash.Domain.Info.resources()
          |> Enum.filter(&AshJsonApi.Resource.Info.type(&1))

        {refs, new_route_schemas} =
          Enum.reduce(resources, {[], []}, fn resource, {refs, schemas} ->
            {new_refs, route_schemas} =
              resource
              |> AshJsonApi.Resource.Info.routes(domains)
              |> Enum.reduce({[], []}, fn route, {refs, route_schemas} ->
                {new_refs, new_route_schema} =
                  route_schema(route, domain, resource, opts)

                {refs ++ new_refs, [new_route_schema | route_schemas]}
              end)

            {refs ++ new_refs, schemas ++ Enum.reverse(route_schemas)}
          end)

        refs = Enum.uniq(refs)

        definitions =
          Enum.reduce(resources, definitions, fn resource, acc ->
            # for now, we only hide resource definitions if they are in refs
            # in the future we should hide any that aren't used
            type = AshJsonApi.Resource.Info.type(resource)

            if "#/definitions/#{type}" in refs do
              Map.put(
                acc,
                type,
                resource_object_schema(resource)
              )
            else
              acc
            end
          end)

        {definitions, new_route_schemas ++ schemas}
      end)

    %{
      "$schema" => "http://json-schema.org/draft-06/schema#",
      "$id" => schema_id,
      "definitions" => definitions,
      "links" => route_schemas
    }
  end

  def route_schema(%{method: method} = route, domain, resource, opts)
      when method in [:delete, :get] do
    {href, properties} = route_href(route, domain, opts)

    {href_schema, query_param_string} = href_schema(route, domain, resource, properties)
    {renders, target_schema} = target_schema(route, domain, resource)

    {renders,
     %{
       "href" => href <> query_param_string,
       "hrefSchema" => href_schema,
       "description" => "pending",
       "method" => route.method |> to_string() |> String.upcase(),
       "rel" => to_string(route.type),
       "targetSchema" => target_schema,
       "headerSchema" => header_schema()
     }}
  end

  def route_schema(route, domain, resource, opts) do
    {href, properties} = route_href(route, domain, opts)

    {href_schema, query_param_string} = href_schema(route, domain, resource, properties)
    {renders, target_schema} = target_schema(route, domain, resource)

    {renders,
     %{
       "href" => href <> query_param_string,
       "hrefSchema" => href_schema,
       "description" => "pending",
       "method" => route.method |> to_string() |> String.upcase(),
       "rel" => to_string(route.type),
       "schema" => route_in_schema(route, domain, resource),
       "targetSchema" => target_schema,
       "headerSchema" => header_schema()
     }}
  end

  defp header_schema do
    # For the content type header - I think we need a regex such as /^(application/vnd.api\+json;?)( profile=[^=]*";)?$/
    # This will ensure that it starts with "application/vnd.api+json" and only includes a profile param
    # I'm sure there will be a ton of edge cases so we may need to make a utility function for this and add unit tests

    # Here are some scenarios we should test:

    # application/vnd.api+json
    # application/vnd.api+json;
    # application/vnd.api+json; charset=\"utf-8\"
    # application/vnd.api+json; profile=\"utf-8\"
    # application/vnd.api+json; profile=\"utf-8\"; charset=\"utf-8\"
    # application/vnd.api+json; profile="foo"; charset=\"utf-8\"
    # application/vnd.api+json; profile="foo"
    # application/vnd.api+json; profile="foo8"
    # application/vnd.api+json; profile="foo";
    # application/vnd.api+json; profile="foo"; charset="bar"
    # application/vnd.api+json; profile="foo;";
    # application/vnd.api+json; profile="foo

    %{
      "type" => "object",
      "properties" => %{
        "content-type" => %{
          "type" => "array",
          "items" => %{
            "type" => "string"
          }
        },
        "accept" => %{
          "type" => "array",
          "items" => %{
            "type" => "string"
          }
        }
      },
      "additionalProperties" => true
    }
  end

  # This is for our representation of a resource *in the response*
  def resource_object_schema(resource) do
    %{
      "description" =>
        Ash.Resource.Info.description(resource) ||
          "A \"Resource object\" representing a #{AshJsonApi.Resource.Info.type(resource)}",
      "type" => "object",
      "required" => ["type", "id"],
      "properties" =>
        %{
          "type" => %{
            "additionalProperties" => false
          },
          "attributes" => attributes(resource),
          "relationships" => relationships(resource)
        }
        |> add_id_field(resource),
      "additionalProperties" => false
    }
  end

  defp base_definitions do
    %{
      "links" => %{
        "type" => "object",
        "additionalProperties" => %{
          "$ref" => "#/definitions/link"
        }
      },
      "link" => %{
        "description" =>
          "A link **MUST** be represented as either: a string containing the link's URL or a link object.",
        "type" => "string"
      },
      "errors" => %{
        "type" => "array",
        "items" => %{
          "$ref" => "#/definitions/error"
        },
        "uniqueItems" => true
      },
      "error" => %{
        "type" => "object",
        "properties" => %{
          "id" => %{
            "description" => "A unique identifier for this particular occurrence of the problem.",
            "type" => "string"
          },
          "links" => %{
            "$ref" => "#/definitions/links"
          },
          "status" => %{
            "description" =>
              "The HTTP status code applicable to this problem, expressed as a string value.",
            "type" => "string"
          },
          "code" => %{
            "description" => "An application-specific error code, expressed as a string value.",
            "type" => "string"
          },
          "title" => %{
            "description" =>
              "A short, human-readable summary of the problem. It **SHOULD NOT** change from occurrence to occurrence of the problem, except for purposes of localization.",
            "type" => "string"
          },
          "detail" => %{
            "description" =>
              "A human-readable explanation specific to this occurrence of the problem.",
            "type" => "string"
          },
          "source" => %{
            "type" => "object",
            "properties" => %{
              "pointer" => %{
                "description" =>
                  "A JSON Pointer [RFC6901] to the associated entity in the request document [e.g. \"/data\" for a primary data object, or \"/data/attributes/title\" for a specific attribute].",
                "type" => "string"
              },
              "parameter" => %{
                "description" => "A string indicating which query parameter caused the error.",
                "type" => "string"
              }
            }
          }
          # "meta" => %{
          #   "$ref" => "#/definitions/meta"
          # }
        },
        "additionalProperties" => false
      }
    }
  end

  defp attributes(resource) do
    %{
      "description" => "An attributes object for a #{AshJsonApi.Resource.Info.type(resource)}",
      "type" => "object",
      "required" => required_attributes(resource),
      "properties" => resource_attributes(resource),
      "additionalProperties" => false
    }
  end

  defp required_attributes(resource) do
    resource
    |> Ash.Resource.Info.public_attributes()
    |> Enum.reject(&(&1.allow_nil? || AshJsonApi.Resource.only_primary_key?(resource, &1.name)))
    |> Enum.map(&to_string(&1.name))
  end

  defp resource_attributes(resource) do
    resource
    |> Ash.Resource.Info.public_attributes()
    |> Enum.concat(Ash.Resource.Info.public_calculations(resource))
    |> Enum.concat(
      Ash.Resource.Info.public_aggregates(resource)
      |> set_aggregate_constraints(resource)
    )
    |> Enum.reject(&AshJsonApi.Resource.only_primary_key?(resource, &1.name))
    |> Enum.reduce(%{}, fn attr, acc ->
      Map.put(acc, to_string(attr.name), resource_attribute_type(attr))
    end)
  end

  @doc false
  def set_aggregate_constraints(aggregates, resource) do
    Enum.map(aggregates, fn %{field: field, relationship_path: relationship_path} = aggregate ->
      field_type_and_constraints =
        with field when not is_nil(field) <- field,
             related when not is_nil(related) <-
               Ash.Resource.Info.related(resource, relationship_path),
             attr when not is_nil(attr) <- Ash.Resource.Info.field(related, field) do
          {attr.type, attr.constraints}
        end

      {field_type, field_constraints} = field_type_and_constraints || {nil, []}

      {:ok, aggregate_type, aggregate_constraints} =
        Ash.Query.Aggregate.kind_to_type(aggregate.kind, field_type, field_constraints)

      Map.merge(aggregate, %{type: aggregate_type, constraints: aggregate_constraints})
    end)
  end

  defp relationships(resource) do
    %{
      "description" => "A relationships object for a #{AshJsonApi.Resource.Info.type(resource)}",
      "type" => "object",
      "properties" => resource_relationships(resource),
      "additionalProperties" => false
    }
  end

  defp resource_relationships(resource) do
    resource
    |> Ash.Resource.Info.public_relationships()
    |> Enum.filter(fn relationship ->
      AshJsonApi.Resource.Info.type(relationship.destination)
    end)
    |> Enum.reduce(%{}, fn rel, acc ->
      data = resource_relationship_field_data(resource, rel)
      links = resource_relationship_link_data(resource, rel)

      object =
        if links do
          %{"data" => data, "links" => links}
        else
          %{"data" => data}
        end

      Map.put(
        acc,
        to_string(rel.name),
        object
      )
    end)
  end

  defp resource_relationship_link_data(_resource, _rel) do
    nil
  end

  defp add_id_field(map, resource) do
    case Ash.Resource.Info.primary_key(resource) do
      [] -> map
      _ -> Map.put(map, "id", %{"type" => "string"})
    end
  end

  defp resource_relationship_field_data(_resource, %{
         type: {:array, _},
         name: name
       }) do
    %{
      "description" => "Input for #{name}",
      "anyOf" => [
        %{
          "type" => "null"
        },
        %{
          "description" => "Identifiers for #{name}",
          "type" => "object",
          "additionalProperties" => false,
          "properties" => %{
            "type" => %{"type" => "string"},
            "id" => %{"type" => "string"},
            "meta" => %{
              "type" => "object",
              "required" => [],
              "additionalProperties" => true
            }
          }
        }
      ]
    }
  end

  defp resource_relationship_field_data(_resource, %{name: name}) do
    %{
      "description" => "An array of inputs for #{name}",
      "type" => "array",
      "items" => %{
        "description" => "Resource identifiers for #{name}",
        "type" => "object",
        # We need to inspect the options here to see if type & id is required
        # "required" => ["type", "id"],
        "properties" => %{
          "type" => %{"type" => "string"},
          "id" => %{"type" => "string"},
          "meta" => %{
            "type" => "object",
            "required" => [],
            "additionalProperties" => true
          }
        }
      },
      "uniqueItems" => true
    }
  end

  defp resource_write_attribute_type(%{type: {:array, type}} = attr, action_type) do
    %{
      "type" => "array",
      "items" =>
        resource_write_attribute_type(
          %{
            attr
            | type: type,
              constraints: attr.constraints[:items] || []
          },
          action_type
        )
    }
  end

  defp resource_write_attribute_type(%{type: type} = attr, action_type) do
    if embedded?(type) do
      embedded_type_input(attr, action_type)
    else
      if :erlang.function_exported(type, :json_write_schema, 1) do
        type.json_write_schema(attr.constraints)
      else
        resource_attribute_type(attr)
      end
    end
  end

  defp resource_attribute_type(%{type: Ash.Type.String}) do
    %{
      "type" => "string"
    }
  end

  defp resource_attribute_type(%{type: Ash.Type.Boolean}) do
    %{
      "type" => ["boolean", "string"],
      "match" => "^(true|false)$"
    }
  end

  defp resource_attribute_type(%{type: Ash.Type.Integer}) do
    %{
      "type" => ["integer", "string"],
      "match" => "^[1-9][0-9]*$"
    }
  end

  defp resource_attribute_type(%{type: Ash.Type.UtcDatetime}) do
    %{
      "type" => "string",
      "format" => "date-time"
    }
  end

  defp resource_attribute_type(%{type: Ash.Type.UUID}) do
    %{
      "type" => "string",
      "format" => "uuid"
    }
  end

  defp resource_attribute_type(%{type: Ash.Type.Atom, constraints: constraints}) do
    if one_of = constraints[:one_of] do
      %{"type" => "string", "enum" => Enum.map(one_of, &to_string/1)}
    else
      %{"type" => "string"}
    end
  end

  defp resource_attribute_type(%{type: {:array, type}} = attr) do
    %{
      "type" => "array",
      "items" =>
        resource_attribute_type(%{attr | type: type, constraints: attr.constraints[:items] || []})
    }
  end

  defp resource_attribute_type(%{type: type} = attr) do
    constraints = attr.constraints

    cond do
      function_exported?(type, :json_schema, 1) ->
        type.json_schema(constraints)

      embedded?(type) ->
        %{
          "type" => "object",
          "properties" => resource_attributes(type),
          "required" => required_attributes(type)
        }

      Ash.Type.NewType.new_type?(type) ->
        new_constraints = Ash.Type.NewType.constraints(type, constraints)
        new_type = Ash.Type.NewType.subtype_of(type)

        resource_attribute_type(Map.merge(attr, %{type: new_type, constraints: new_constraints}))

      Spark.implements_behaviour?(type, Ash.Type.Enum) ->
        %{"type" => "string", "enum" => Enum.map(type.values(), &to_string/1)}

      true ->
        %{
          "type" => "any"
        }
    end
  end

  defp embedded_type_input(%{type: resource} = attribute, action_type) do
    attribute = %{
      attribute
      | constraints: Ash.Type.NewType.constraints(resource, attribute.constraints)
    }

    resource = Ash.Type.NewType.subtype_of(resource)

    create_action =
      case attribute.constraints[:create_action] do
        nil ->
          Ash.Resource.Info.primary_action(resource, :create)

        name ->
          Ash.Resource.Info.action(resource, name)
      end

    update_action =
      case attribute.constraints[:update_action] do
        nil ->
          Ash.Resource.Info.primary_action(resource, :update)

        name ->
          Ash.Resource.Info.action(resource, name)
      end

    create_write_attributes =
      if create_action do
        write_attributes(resource, create_action.arguments, create_action)
      else
        %{}
      end

    update_write_attributes =
      if update_action do
        write_attributes(resource, update_action.arguments, update_action)
      else
        %{}
      end

    create_required_attributes =
      if create_action do
        required_write_attributes(resource, create_action.arguments, create_action)
      else
        []
      end

    update_required_attributes =
      if update_action do
        required_write_attributes(resource, update_action.arguments, update_action)
      else
        []
      end

    required =
      if action_type == :create do
        create_required_attributes
      else
        create_required_attributes
        |> MapSet.new()
        |> MapSet.intersection(MapSet.new(update_required_attributes))
        |> Enum.to_list()
      end

    %{
      "type" => "object",
      "required" => required,
      "properties" =>
        Map.merge(create_write_attributes, update_write_attributes, fn _k, l, r ->
          %{
            "anyOf" => [
              l,
              r
            ]
          }
          |> unwrap_any_of()
        end)
    }
  end

  defp unwrap_any_of(%{"anyOf" => options}) do
    {options_remaining, options_to_add} =
      Enum.reduce(options, {[], []}, fn schema, {options, to_add} ->
        case schema do
          %{"anyOf" => _} = schema ->
            case unwrap_any_of(schema) do
              %{"anyOf" => nested_options} ->
                {options, [nested_options | to_add]}

              schema ->
                {options, [schema | to_add]}
            end

          _ ->
            {[schema | to_add], options}
        end
      end)

    case options_remaining ++ options_to_add do
      [] ->
        %{"type" => "any"}

      [one] ->
        one

      many ->
        %{"anyOf" => many}
    end
  end

  defp href_schema(route, domain, resource, required_properties) do
    base_properties =
      Enum.into(required_properties, %{}, fn prop ->
        {prop, %{"type" => "string"}}
      end)

    {query_param_properties, query_param_string, required} =
      query_param_properties(route, domain, resource, required_properties)

    {%{
       "required" => required_properties ++ required,
       "properties" => Map.merge(query_param_properties, base_properties)
     }, query_param_string}
  end

  defp query_param_properties(%{type: :index} = route, domain, resource, properties) do
    %{
      "page" => %{
        "type" => "object",
        "properties" => page_props(domain, resource)
      },
      "include" => %{
        "type" => "string"
        # "format" => include_format(resource)
      }
    }
    |> add_filter(route, resource)
    |> add_sort(route, resource)
    |> Map.merge(Map.new(properties, &{&1, %{"type" => "any"}}))
    |> add_read_arguments(route, resource)
    |> with_keys()
  end

  defp query_param_properties(%{type: type}, _, resource, properties)
       when type in [:post_to_relationship, :patch_relationship, :delete_from_relationship] do
    %{}
    |> add_route_properties(resource, properties)
    |> with_keys()
  end

  defp query_param_properties(route, _domain, resource, properties) do
    props = %{
      "include" => %{
        "type" => "string"
        # "format" => include_format(resource)
      }
    }

    if route.type in [:get, :related] do
      props
      |> add_route_properties(resource, properties)
      |> add_read_arguments(route, resource)
      |> with_keys()
    else
      with_keys(props)
    end
  end

  defp add_filter(properties, route, resource) do
    if route.derive_filter? && read_action?(resource, route) &&
         AshJsonApi.Resource.Info.derive_filter?(resource) do
      Map.put(properties, "filter", %{
        "type" => "object"
      })
    else
      properties
    end
  end

  defp add_sort(properties, route, resource) do
    if route.derive_sort? && read_action?(resource, route) &&
         AshJsonApi.Resource.Info.derive_sort?(resource) do
      Map.put(properties, "sort", %{
        "type" => "string",
        "format" => sort_format(resource)
      })
    else
      properties
    end
  end

  defp read_action?(resource, route) do
    action = Ash.Resource.Info.action(resource, route.action)
    action && action.type == :read
  end

  defp add_route_properties(keys, resource, properties) do
    Enum.reduce(properties, keys, fn property, keys ->
      spec =
        if attribute = Ash.Resource.Info.public_attribute(resource, property) do
          resource_attribute_type(attribute)
        else
          %{"type" => "any"}
        end

      Map.put(keys, property, spec)
    end)
  end

  defp add_read_arguments(props, route, resource) do
    action = Ash.Resource.Info.action(resource, route.action)

    {
      action.arguments
      |> Enum.filter(& &1.public?)
      |> Enum.reduce(props, fn argument, props ->
        Map.put(
          props,
          to_string(argument.name),
          resource_write_attribute_type(argument, argument.type)
        )
      end),
      action.arguments
      |> Enum.filter(& &1.public?)
      |> Enum.reject(& &1.allow_nil?)
      |> Enum.map(&"#{&1.name}")
    }
  end

  defp with_keys({map, required}) do
    {map, "{" <> Enum.map_join(map, ",", &elem(&1, 0)) <> "}", required}
  end

  defp with_keys(map) do
    {map, "{" <> Enum.map_join(map, ",", &elem(&1, 0)) <> "}", []}
  end

  defp sort_format(resource) do
    sorts = sortable_fields(resource)

    "(#{Enum.map_join(sorts, "|", & &1.name)}),*"
  end

  defp page_props(_domain, _resource) do
    %{
      "limit" => %{
        "type" => "string",
        "pattern" => "^[0-9]*$"
      },
      "offset" => %{
        "type" => "string",
        "pattern" => "^[0-9]*$"
      }
    }
  end

  defp route_in_schema(%{type: :route, action: action} = route, _domain, resource) do
    action = Ash.Resource.Info.action(resource, action)
    required_write_props = required_write_attributes(resource, action.arguments, action, route)

    required_outer_props =
      if Enum.empty?(required_write_props) do
        []
      else
        ["data"]
      end

    %{
      "type" => "object",
      "required" => required_outer_props,
      "additionalProperties" => false,
      "properties" => %{
        "data" => %{
          "type" => "object",
          "additionalProperties" => false,
          "properties" => write_attributes(resource, action.arguments, action, route),
          "required" => required_write_props
        }
      }
    }
  end

  defp route_in_schema(%{type: type}, _domain, _resource) when type in [:index, :get, :delete] do
    %{}
  end

  defp route_in_schema(
         %{
           type: type,
           action: action,
           relationship_arguments: relationship_arguments
         } = route,
         _domain,
         resource
       )
       when type in [:post] do
    action = Ash.Resource.Info.action(resource, action)

    non_relationship_arguments =
      Enum.reject(action.arguments, &has_relationship_argument?(relationship_arguments, &1.name))

    %{
      "type" => "object",
      "required" => ["data"],
      "additionalProperties" => false,
      "properties" => %{
        "data" => %{
          "type" => "object",
          "additionalProperties" => false,
          "properties" => %{
            "type" => %{
              "const" => AshJsonApi.Resource.Info.type(resource)
            },
            "attributes" => %{
              "type" => "object",
              "additionalProperties" => false,
              "required" =>
                required_write_attributes(resource, non_relationship_arguments, action, route),
              "properties" =>
                write_attributes(resource, non_relationship_arguments, action, route)
            },
            "relationships" => %{
              "type" => "object",
              "required" =>
                required_relationship_attributes(resource, relationship_arguments, action),
              "additionalProperties" => false,
              "properties" => write_relationships(resource, relationship_arguments, action)
            }
          }
        }
      }
    }
  end

  defp route_in_schema(
         %{
           type: type,
           action: action,
           relationship_arguments: relationship_arguments
         } = route,
         _domain,
         resource
       )
       when type in [:patch] do
    action = Ash.Resource.Info.action(resource, action)

    non_relationship_arguments =
      Enum.reject(action.arguments, &has_relationship_argument?(relationship_arguments, &1.name))

    %{
      "type" => "object",
      "required" => ["data"],
      "additionalProperties" => false,
      "properties" => %{
        "data" => %{
          "type" => "object",
          "additionalProperties" => false,
          "properties" =>
            %{
              "type" => %{
                "const" => AshJsonApi.Resource.Info.type(resource)
              },
              "attributes" => %{
                "type" => "object",
                "additionalProperties" => false,
                "required" =>
                  required_write_attributes(resource, non_relationship_arguments, action, route),
                "properties" =>
                  write_attributes(resource, non_relationship_arguments, action, route)
              },
              "relationships" => %{
                "type" => "object",
                "additionalProperties" => false,
                "required" =>
                  required_relationship_attributes(resource, relationship_arguments, action),
                "properties" => write_relationships(resource, relationship_arguments, action)
              }
            }
            |> add_id_field(resource)
        }
      }
    }
  end

  defp route_in_schema(
         %{type: type, relationship: relationship},
         _domain,
         resource
       )
       when type in [:post_to_relationship, :patch_relationship, :delete_from_relationship] do
    case Ash.Resource.Info.public_relationship(resource, relationship) do
      nil ->
        raise ArgumentError, """
        Expected resource  #{resource} to define relationship #{relationship}.

        Please verify all json_api relationship routes have relationships
        """

      other ->
        relationship_resource_identifiers(other)
    end
  end

  defp relationship_resource_identifiers(relationship) when is_map(relationship) do
    %{
      "type" => "object",
      "required" => ["data"],
      "additionalProperties" => false,
      "properties" => %{
        "data" => %{
          "type" => "array",
          "items" => %{
            "type" => "object",
            "required" => ["id", "type"],
            "additionalProperties" => false,
            "properties" =>
              %{
                "type" => %{
                  "const" => AshJsonApi.Resource.Info.type(relationship.destination)
                },
                "meta" => %{
                  "type" => "object"
                  #   "properties" => join_attribute_properties(relationship),
                  #   "additionalProperties" => false
                }
              }
              |> add_id_field(relationship.destination)
          }
        }
      }
    }
  end

  defp required_write_attributes(resource, arguments, action, route \\ nil) do
    attributes =
      if action.type in [:action, :read] do
        []
      else
        resource
        |> Ash.Resource.Info.attributes()
        |> Enum.filter(&(&1.name in action.accept && &1.writable?))
        |> Enum.reject(
          &(&1.allow_nil? || not is_nil(&1.default) || &1.generated? ||
              &1.name in action.allow_nil_input)
        )
        |> Enum.map(&to_string(&1.name))
      end

    arguments =
      arguments
      |> without_path_arguments(action, route)
      |> Enum.reject(& &1.allow_nil?)
      |> Enum.map(&to_string(&1.name))

    Enum.uniq(
      attributes ++ arguments ++ Enum.map(Map.get(action, :require_attributes, []), &to_string/1)
    )
  end

  defp write_attributes(resource, arguments, action, route \\ nil) do
    attributes =
      if action.type in [:action, :read] do
        %{}
      else
        resource
        |> Ash.Resource.Info.attributes()
        |> Enum.filter(&(&1.name in action.accept && &1.writable?))
        |> Enum.reduce(%{}, fn attribute, acc ->
          Map.put(
            acc,
            to_string(attribute.name),
            resource_write_attribute_type(attribute, action.type)
          )
        end)
      end

    arguments
    |> without_path_arguments(action, route)
    |> Enum.reduce(attributes, fn argument, attributes ->
      Map.put(
        attributes,
        to_string(argument.name),
        resource_write_attribute_type(argument, :create)
      )
    end)
  end

  defp without_path_arguments(arguments, %{type: type}, %{route: route, type: route_type})
       when type == :action or route_type == :post do
    route_params =
      route
      |> Path.split()
      |> Enum.filter(&String.starts_with?(&1, ":"))
      |> Enum.map(&String.trim_leading(&1, ":"))

    Enum.reject(arguments, fn argument ->
      to_string(argument.name) in route_params
    end)
  end

  defp without_path_arguments(arguments, _, _), do: arguments

  defp required_relationship_attributes(_resource, relationship_arguments, action) do
    action.arguments
    |> Enum.filter(&has_relationship_argument?(relationship_arguments, &1.name))
    |> Enum.reject(& &1.allow_nil?)
    |> Enum.map(&to_string(&1.name))
  end

  defp write_relationships(resource, relationship_arguments, action) do
    action.arguments
    |> Enum.filter(&has_relationship_argument?(relationship_arguments, &1.name))
    |> Enum.reduce(%{}, fn argument, acc ->
      data = resource_relationship_field_data(resource, argument)

      object = %{"data" => data, "links" => %{"type" => "any"}}

      Map.put(
        acc,
        to_string(argument.name),
        object
      )
    end)
  end

  defp has_relationship_argument?(relationship_arguments, name) do
    Enum.any?(relationship_arguments, fn
      {:id, ^name} -> true
      ^name -> true
      _ -> false
    end)
  end

  defp target_schema(route, _domain, resource) do
    case route.type do
      :route ->
        action = Ash.Resource.Info.action(resource, route.action)

        if action.returns do
          return_type =
            resource_attribute_type(%{type: action.returns, constraints: action.constraints})

          full_return_type =
            if route.wrap_in_result? do
              %{
                "type" => "object",
                "properties" => %{
                  "result" => return_type
                },
                "required" => ["result"]
              }
            else
              return_type
            end

          {[],
           %{
             "oneOf" => [
               full_return_type,
               %{
                 "$ref" => "#/definitions/errors"
               }
             ]
           }}
        else
          {[],
           %{
             "oneOf" => [
               %{
                 type: :object,
                 properties: %{
                   success: %{enum: [true]}
                 },
                 required: ["success"]
               },
               %{
                 "$ref" => "#/definitions/errors"
               }
             ]
           }}
        end

      :index ->
        ref = "#/definitions/#{AshJsonApi.Resource.Info.type(resource)}"

        {[ref],
         %{
           "oneOf" => [
             %{
               "data" => %{
                 "description" =>
                   "An array of resource objects representing a #{AshJsonApi.Resource.Info.type(resource)}",
                 "type" => "array",
                 "items" => %{
                   "$ref" => ref
                 },
                 "uniqueItems" => true
               },
               "meta" => %{
                 "type" => "object"
               }
             },
             %{
               "$ref" => "#/definitions/errors"
             }
           ]
         }}

      :delete ->
        {[],
         %{
           "oneOf" => [
             nil,
             %{
               "$ref" => "#/definitions/errors"
             }
           ]
         }}

      type when type in [:post_to_relationship, :patch_relationship, :delete_from_relationship] ->
        {[],
         resource
         |> Ash.Resource.Info.public_relationship(route.relationship)
         |> relationship_resource_identifiers()}

      _ ->
        ref = "#/definitions/#{AshJsonApi.Resource.Info.type(resource)}"

        {[ref],
         %{
           "oneOf" => [
             %{
               "data" => %{
                 "$ref" => ref
               },
               "meta" => %{
                 "type" => "object"
               }
             },
             %{
               "$ref" => "#/definitions/errors"
             }
           ]
         }}
    end
  end

  @doc false
  def route_href(route, domain, opts) do
    {path, path_params} =
      domain
      |> AshJsonApi.Domain.Info.prefix()
      |> Kernel.||(opts[:prefix])
      |> Kernel.||("")
      |> Path.join(route.route)
      |> Path.split()
      |> Enum.reduce({[], []}, fn part, {path, path_params} ->
        case part do
          ":" <> name -> {["{#{name}}" | path], [name | path_params]}
          part -> {[part | path], path_params}
        end
      end)

    case path do
      [] ->
        {"/", path_params}

      path ->
        {path |> Enum.reverse() |> Path.join() |> prepend_slash(), path_params}
    end
  end

  defp prepend_slash("/" <> _ = path), do: path
  defp prepend_slash(path), do: "/" <> path

  @doc false
  def sortable_fields(resource) do
    resource
    |> Ash.Resource.Info.public_attributes()
    |> Enum.concat(Ash.Resource.Info.public_calculations(resource))
    |> Enum.concat(Ash.Resource.Info.public_aggregates(resource))
    |> Enum.filter(&sortable?(&1, resource))
  end

  defp sortable?(%Ash.Resource.Aggregate{} = aggregate, resource) do
    attribute =
      with field when not is_nil(field) <- aggregate.field,
           related when not is_nil(related) <-
             Ash.Resource.Info.related(resource, aggregate.relationship_path),
           attr when not is_nil(attr) <- Ash.Resource.Info.field(related, aggregate.field) do
        attr
      end

    field_type =
      if attribute do
        attribute.type
      end

    field_constraints =
      if attribute do
        attribute.constraints
      end

    {:ok, type, constraints} =
      Aggregate.kind_to_type(aggregate.kind, field_type, field_constraints)

    sortable?(
      %Ash.Resource.Attribute{name: aggregate.name, type: type, constraints: constraints},
      resource
    )
  end

  defp sortable?(%{type: {:array, _}}, _), do: false
  defp sortable?(%{sortable?: false}, _), do: false
  defp sortable?(%{type: Ash.Type.Union}, _), do: false

  defp sortable?(%Ash.Resource.Calculation{type: type, calculation: {module, _opts}}, _) do
    Code.ensure_compiled!(module)
    !embedded?(type) && function_exported?(module, :expression, 2)
  end

  defp sortable?(%{type: type} = attribute, resource) do
    if Ash.Type.NewType.new_type?(type) do
      sortable?(
        %{
          attribute
          | constraints: Ash.Type.NewType.constraints(type, attribute.constraints),
            type: Ash.Type.NewType.subtype_of(type)
        },
        resource
      )
    else
      !embedded?(type)
    end
  end

  defp sortable?(_, _), do: false

  @doc false
  def embedded?({:array, resource_or_type}) do
    embedded?(resource_or_type)
  end

  def embedded?(resource_or_type) do
    if Ash.Resource.Info.resource?(resource_or_type) do
      true
    else
      Ash.Type.embedded_type?(resource_or_type)
    end
  end
end
