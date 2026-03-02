# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Resource.Info do
  @moduledoc "Introspection helpers for AshJsonApi.Resource"

  alias Spark.Dsl.Extension

  def type(resource) do
    Extension.get_opt(resource, [:json_api], :type, nil, false)
  end

  def derive_filter?(resource) do
    Extension.get_opt(resource, [:json_api], :derive_filter?, true, false)
  end

  def derive_sort?(resource) do
    Extension.get_opt(resource, [:json_api], :derive_sort, true, false)
  end

  def always_include_linkage(resource) do
    Extension.get_opt(resource, [:json_api], :always_include_linkage, [], false)
  end

  def includes(resource) do
    Extension.get_opt(resource, [:json_api], :includes, [], false)
  end

  def paginated_includes(resource) do
    Extension.get_opt(resource, [:json_api], :paginated_includes, [], false)
  end

  def action_names_in_schema(resource) do
    Extension.get_opt(resource, [:json_api], :action_names_in_schema, [], false)
  end

  def base_route(resource) do
    Extension.get_opt(resource, [:json_api, :routes], :base, "/", false)
  end

  def primary_key_fields(resource) do
    Extension.get_opt(resource, [:json_api, :primary_key], :keys, [], false)
  end

  def primary_key_delimiter(resource) do
    Extension.get_opt(resource, [:json_api, :primary_key], :delimiter, [], false)
  end

  def routes(resource, domain_or_domains \\ []) do
    module =
      if is_atom(resource) do
        resource
      else
        Spark.Dsl.Extension.get_persisted(resource, :module)
      end

    domain_or_domains
    |> List.wrap()
    |> Enum.flat_map(&AshJsonApi.Domain.Info.routes/1)
    |> Enum.filter(&(&1.resource == module))
    |> Enum.concat(Extension.get_entities(resource, [:json_api, :routes]))
  end

  def include_nil_values?(resource) do
    Extension.get_opt(resource, [:json_api], :include_nil_values?, nil, true)
  end

  def default_fields(resource) do
    Extension.get_opt(resource, [:json_api], :default_fields, nil, true)
  end

  defp camelize(name) do
    camelized = name |> to_string() |> Macro.camelize()
    {first, rest} = String.split_at(camelized, 1)
    String.downcase(first) <> rest
  end

  defp dasherize(name) do
    name |> to_string() |> String.replace("_", "-")
  end

  @doc """
  Returns the `field_names` config for the resource: a keyword list, a 1-arity function,
  or one of the atoms `:camelize` / `:dasherize` (resolved to the corresponding function).
  """
  def field_names(resource) do
    case Extension.get_opt(resource, [:json_api], :field_names, [], true) do
      :camelize -> &camelize/1
      :dasherize -> &dasherize/1
      other -> other
    end
  end

  @doc """
  Returns the `argument_names` config for the resource: a keyword list, a 2-arity function,
  or one of the atoms `:camelize` / `:dasherize` (resolved to the corresponding function).
  """
  def argument_names(resource) do
    case Extension.get_opt(resource, [:json_api], :argument_names, [], true) do
      :camelize -> fn _action, name -> camelize(name) end
      :dasherize -> fn _action, name -> dasherize(name) end
      other -> other
    end
  end

  @doc """
  Returns the `calculation_argument_names` config for the resource: a keyword list, a 2-arity function,
  or one of the atoms `:camelize` / `:dasherize` (resolved to the corresponding function).
  """
  def calculation_argument_names(resource) do
    case Extension.get_opt(resource, [:json_api], :calculation_argument_names, [], true) do
      :camelize -> fn _calc, name -> camelize(name) end
      :dasherize -> fn _calc, name -> dasherize(name) end
      other -> other
    end
  end

  @doc """
  Converts an Ash atom field name (attribute, calculation, aggregate) to its JSON:API
  string key, applying any `field_names` mapping configured on the resource.
  """
  def field_to_json_key(resource, field_name) do
    names = field_names(resource)

    cond do
      is_function(names, 1) -> to_string(names.(field_name))
      is_list(names) -> to_string(names[field_name] || field_name)
      true -> to_string(field_name)
    end
  end

  @doc """
  Converts a JSON:API string key to an Ash atom field name, applying the reverse of any
  `field_names` mapping configured on the resource. Returns `nil` if not found.
  """
  def json_key_to_field(resource, json_key) do
    names = field_names(resource)

    all_fields =
      Ash.Resource.Info.public_attributes(resource) ++
        Ash.Resource.Info.public_calculations(resource) ++
        Ash.Resource.Info.public_aggregates(resource)

    Enum.find_value(all_fields, fn field ->
      if apply_field_name_mapping(names, field.name) == json_key, do: field.name
    end)
  end

  @doc """
  Converts an Ash argument atom name to its JSON:API string key, applying any
  `argument_names` mapping configured on the resource for the given action.
  """
  def argument_to_json_key(resource, action_name, arg_name) do
    names = argument_names(resource)
    apply_argument_name_mapping(names, action_name, arg_name)
  end

  @doc """
  Converts a JSON:API string key to an Ash argument atom name for the given action,
  applying the reverse of any `argument_names` mapping. Returns `nil` if not found.
  """
  def json_key_to_argument(resource, action_name, json_key) do
    names = argument_names(resource)
    action = Ash.Resource.Info.action(resource, action_name)

    if action do
      Enum.find_value(action.arguments, fn arg ->
        if apply_argument_name_mapping(names, action_name, arg.name) == json_key, do: arg.name
      end)
    end
  end

  @doc """
  Converts an Ash calculation argument atom name to its JSON:API string key, applying any
  `calculation_argument_names` mapping configured on the resource for the given calculation.
  """
  def calculation_argument_to_json_key(resource, calc_name, arg_name) do
    names = calculation_argument_names(resource)
    apply_argument_name_mapping(names, calc_name, arg_name)
  end

  @doc """
  Converts a JSON:API string key to an Ash argument atom name for the given calculation,
  applying the reverse of any `calculation_argument_names` mapping. Returns `nil` if not found.
  """
  def json_key_to_calculation_argument(resource, calc_name, json_key) do
    names = calculation_argument_names(resource)

    case Ash.Resource.Info.public_calculation(resource, calc_name) do
      %{arguments: args} ->
        Enum.find_value(args, fn arg ->
          if apply_argument_name_mapping(names, calc_name, arg.name) == json_key, do: arg.name
        end)

      nil ->
        nil
    end
  end

  @doc """
  Returns a ref transformer function suitable for the `:ref_transformer` option of
  `Ash.Filter.parse_input/3` and `Ash.Query.filter_input/3`. The returned function maps
  user-facing JSON:API field/argument names back to their internal Ash atom names using
  the resource's `field_names` and `argument_names` configuration.
  """
  def filter_ref_transformer do
    fn resource, ref ->
      case ref do
        {:calculation_argument, calc_name, arg_name} ->
          json_key_to_calculation_argument(resource, calc_name, to_string(arg_name))

        field_name ->
          json_key_to_field(resource, to_string(field_name))
      end
    end
  end

  # Applies the name mapping for a single field, returning the JSON:API string.
  @doc false
  def apply_field_name_mapping(names, field_name) when is_function(names, 1) do
    to_string(names.(field_name))
  end

  def apply_field_name_mapping(names, field_name) when is_list(names) do
    to_string(names[field_name] || field_name)
  end

  def apply_field_name_mapping(_names, field_name) do
    to_string(field_name)
  end

  # Applies the argument name mapping for a single argument, returning the JSON:API string.
  @doc false
  def apply_argument_name_mapping(names, action_name, arg_name) when is_function(names, 2) do
    to_string(names.(action_name, arg_name))
  end

  def apply_argument_name_mapping(names, action_name, arg_name) when is_list(names) do
    to_string((names[action_name] || [])[arg_name] || arg_name)
  end

  def apply_argument_name_mapping(_names, _action_name, arg_name) do
    to_string(arg_name)
  end
end
