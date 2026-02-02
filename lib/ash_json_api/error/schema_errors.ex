# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Error.SchemaErrors do
  @moduledoc false
  def all_errors(%{reason: reason}, format \\ :parameter) do
    reason
    |> JsonXema.ValidationError.travers_errors([], fn error, path, acc ->
      # Special handling for required errors - return proper required errors
      case error do
        %{required: fields} ->
          required_errors =
            Enum.map(fields, fn field ->
              field_path = path ++ [field]

              %{
                path: format_path_name(format, field_path),
                message: "is required",
                code: "required",
                title: "Required"
              }
            end)

          Enum.concat(required_errors, acc)

        _ ->
          # For all other errors, use the original format
          error
          |> error_messages(path)
          |> Enum.reduce(acc, fn message, acc ->
            [%{path: format_path_name(format, path), message: message} | acc]
          end)
      end
    end)
    |> List.flatten()
  end

  defp format_path_name(:parameter, [path | rest]) do
    Enum.join([path | Enum.map(rest, fn elem -> "[#{elem}]" end)], "")
  end

  defp format_path_name(:parameter, []), do: ""

  defp format_path_name(:json_pointer, path) do
    "/" <> Enum.join(path, "/")
  end

  defp error_messages(reason, path, acc \\ [])

  defp error_messages(%{exclusiveMinimum: minimum, value: value}, path, acc) do
    msg = "Value #{inspect(value)} is not greater than #{inspect(minimum)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{exclusiveMaximum: maximum, value: value}, path, acc) do
    msg = "Value #{inspect(value)} is not less than #{inspect(maximum)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{maximum: maximum, value: value}, path, acc) do
    msg = "Value #{inspect(value)} exceeds maximum value of #{inspect(maximum)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{minimum: minimum, value: value}, path, acc) do
    msg = "Value #{inspect(value)} is less than minimum value of #{inspect(minimum)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{multipleOf: multiple_of, value: value}, path, acc) do
    msg = "Value #{inspect(value)} is not a multiple of #{inspect(multiple_of)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{type: type, value: value}, path, acc) do
    msg = "Expected #{inspect(value)} to be #{type_name(type)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{enum: _enum, value: value}, path, acc) do
    msg = "Value #{inspect(value)} is not allowed in enum"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{const: const, value: value}, path, acc) do
    msg = "Expected the value to be #{inspect(const)}, got #{inspect(value)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{maxLength: max_length, value: value}, path, acc) do
    msg = "Expected maximum length of #{max_length}, got #{inspect(value)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{minLength: min_length, value: value}, path, acc) do
    msg = "Expected minimum length of #{min_length}, got #{inspect(value)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{pattern: pattern, value: value}, path, acc) do
    msg = "String #{inspect(value)} does not match pattern #{inspect(pattern)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{format: format, value: value}, path, acc) do
    msg = "String #{inspect(value)} does not validate against format #{inspect(format)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{then: _error}, path, acc) do
    ["Schema for then does not match#{at_path(path)}" | acc]
  end

  defp error_messages(%{else: _error}, path, acc) do
    ["Schema for else does not match#{at_path(path)}" | acc]
  end

  defp error_messages(%{not: :ok, value: value}, path, acc) do
    msg = "Value is valid against schema from not, got #{inspect(value)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{contains: _errors}, path, acc) do
    ["No items match contains#{at_path(path)}" | acc]
  end

  defp error_messages(%{anyOf: _errors}, path, acc) do
    ["No match of any schema" <> at_path(path) | acc]
  end

  defp error_messages(%{allOf: _errors}, path, acc) do
    ["No match of all schema#{at_path(path)}" | acc]
  end

  defp error_messages(%{oneOf: {:error, _errors}}, path, acc) do
    ["No match of any schema#{at_path(path)}" | acc]
  end

  defp error_messages(%{oneOf: {:ok, success}}, path, acc) do
    msg = "More as one schema matches (indexes: #{inspect(success)})"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{required: _required}, _path, acc) do
    # Handled specially in all_errors/2
    acc
  end

  defp error_messages(%{propertyNames: errors, value: _value}, path, acc) do
    errors
    |> Enum.reduce(acc, fn {key, _reason}, acc ->
      ["Invalid property name: #{inspect(key)}#{at_path(path)}" | acc]
    end)
  end

  defp error_messages(%{dependencies: deps}, path, acc) do
    deps
    |> Enum.reduce(acc, fn
      {key, reason}, acc when is_map(reason) ->
        ["Dependencies for #{inspect(key)} failed#{at_path(path)}" | acc]

      {key, reason}, acc ->
        [
          "Dependencies for #{inspect(key)} failed#{at_path(path)} - Missing required key #{inspect(reason)}."
          | acc
        ]
    end)
  end

  defp error_messages(%{minItems: min, value: value}, path, acc) do
    msg = "Expected at least #{inspect(min)} items, got #{inspect(value)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{maxItems: max, value: value}, path, acc) do
    msg = "Expected at most #{inspect(max)} items, got #{inspect(value)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{uniqueItems: true, value: value}, path, acc) do
    msg = "Expected items to be unique, got #{inspect(value)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{additionalItems: false}, path, acc) do
    msg = "Schema does not allow additional items"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{additionalProperties: false}, path, acc) do
    msg = "Expected only defined properties, got key #{inspect(path)}"
    [msg <> "." | acc]
  end

  defp error_messages(%{properties: _properties}, _path, acc) do
    # Skip nested properties errors to avoid duplicates
    acc
  end

  defp error_messages(%{minProperties: min_properties, value: value}, path, acc) do
    msg = "Expected at least #{min_properties} properties, got #{map_size(value)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{maxProperties: max_properties, value: value}, path, acc) do
    msg = "Expected at most #{max_properties} properties, got #{map_size(value)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(_error, path, acc) do
    msg = "Unexpected error"
    [msg <> at_path(path) | acc]
  end

  defp at_path([]), do: "."

  defp at_path(path), do: ", at #{inspect(path)}."

  defp type_name(types) when is_list(types) do
    Enum.map_join(types, " or ", &type_name/1)
  end

  defp type_name(type) when is_binary(type), do: type
  defp type_name(type) when is_atom(type), do: Atom.to_string(type)
end
