defmodule AshJsonApi.Error.SchemaErrors do
  def all_errors(%{reason: reason}, format \\ :parameter) do
    reason
    |> JsonXema.ValidationError.travers_errors([], fn error, path, acc ->
      error
      |> error_messages(path)
      |> Enum.reduce(acc, fn message, acc ->
        [%{path: format_path_name(format, path), message: message} | acc]
      end)
    end)
    |> List.flatten()
  end

  defp format_path_name(:parameter, [path | rest]) do
    Enum.join([path | Enum.map(rest, fn elem -> "[#{elem}]" end)], "")
  end

  defp format_path_name(:json_pointer, path) do
    Enum.join(path, "/")
  end

  defp error_messages(reason, path, acc \\ [])

  defp error_messages(%{exclusiveMinimum: minimum, value: value}, path, acc)
       when minimum == value do
    msg = "Value #{inspect(minimum)} equals exclusive minimum value of #{inspect(minimum)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{minimum: minimum, exclusiveMinimum: true, value: value}, path, acc)
       when minimum == value do
    msg = "Value #{inspect(value)} equals exclusive minimum value of #{inspect(minimum)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{minimum: minimum, exclusiveMinimum: true, value: value}, path, acc) do
    msg = "Value #{inspect(value)} is less than minimum value of #{inspect(minimum)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{exclusiveMinimum: minimum, value: value}, path, acc) do
    msg = "Value #{inspect(value)} is less than minimum value of #{inspect(minimum)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{minimum: minimum, value: value}, path, acc) do
    msg = "Value #{inspect(value)} is less than minimum value of #{inspect(minimum)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{exclusiveMaximum: maximum, value: value}, path, acc)
       when maximum == value do
    msg = "Value #{inspect(maximum)} equals exclusive maximum value of #{inspect(maximum)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{maximum: maximum, exclusiveMaximum: true, value: value}, path, acc)
       when maximum == value do
    msg = "Value #{inspect(value)} equals exclusive maximum value of #{inspect(maximum)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{maximum: maximum, exclusiveMaximum: true, value: value}, path, acc) do
    msg = "Value #{inspect(value)} exceeds maximum value of #{inspect(maximum)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{exclusiveMaximum: maximum, value: value}, path, acc) do
    msg = "Value #{inspect(value)} exceeds maximum value of #{inspect(maximum)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{maximum: maximum, value: value}, path, acc) do
    msg = "Value #{inspect(value)} exceeds maximum value of #{inspect(maximum)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{maxLength: max, value: value}, path, acc) do
    msg = "Expected maximum length of #{inspect(max)}, got #{inspect(value)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{minLength: min, value: value}, path, acc) do
    msg = "Expected minimum length of #{inspect(min)}, got #{inspect(value)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{multipleOf: multiple_of, value: value}, path, acc) do
    msg = "Value #{inspect(value)} is not a multiple of #{inspect(multiple_of)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{enum: _enum, value: value}, path, acc) do
    msg = "Value #{inspect(value)} is not defined in enum"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{minProperties: min, value: value}, path, acc) do
    msg = "Expected at least #{inspect(min)} properties, got #{inspect(value)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{maxProperties: max, value: value}, path, acc) do
    msg = "Expected at most #{inspect(max)} properties, got #{inspect(value)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{additionalProperties: false}, path, acc) do
    msg = "Expected only defined properties, got key #{inspect(path)}."
    [msg | acc]
  end

  defp error_messages(%{additionalItems: false}, path, acc) do
    msg = "Unexpected additional item"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{format: format, value: value}, path, acc) do
    msg = "String #{inspect(value)} does not validate against format #{inspect(format)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{then: error}, path, acc) do
    msg = ["Schema for then does not match#{at_path(path)}"]

    error =
      error
      |> JsonXema.ValidationError.travers_errors([], &error_messages/3, path: path)
      |> indent()

    Enum.concat([error, msg, acc])
  end

  defp error_messages(%{else: error}, path, acc) do
    msg = ["Schema for else does not match#{at_path(path)}"]

    error =
      error
      |> JsonXema.ValidationError.travers_errors([], &error_messages/3, path: path)
      |> indent()

    Enum.concat([error, msg, acc])
  end

  defp error_messages(%{not: :ok, value: value}, path, acc) do
    msg = "Value is valid against schema from not, got #{inspect(value)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{contains: errors}, path, acc) do
    msg = ["No items match contains#{at_path(path)}"]

    errors =
      errors
      |> Enum.map(fn {index, reason} ->
        JsonXema.ValidationError.travers_errors(reason, [], &error_messages/3,
          path: path ++ [index]
        )
      end)
      |> Enum.reverse()
      |> indent()

    Enum.concat([errors, msg, acc])
  end

  defp error_messages(%{anyOf: errors}, path, acc) do
    msg = ["No match of any schema" <> at_path(path)]

    errors =
      errors
      |> Enum.flat_map(fn reason ->
        reason
        |> JsonXema.ValidationError.travers_errors([], &error_messages/3, path: path)
        |> Enum.reverse()
      end)
      |> Enum.reverse()
      |> indent()

    Enum.concat([errors, msg, acc])
  end

  defp error_messages(%{allOf: errors}, path, acc) do
    msg = ["No match of all schema#{at_path(path)}"]

    errors =
      errors
      |> Enum.map(fn reason ->
        JsonXema.ValidationError.travers_errors(reason, [], &error_messages/3, path: path)
      end)
      |> Enum.reverse()
      |> indent()

    Enum.concat([errors, msg, acc])
  end

  defp error_messages(%{oneOf: {:error, errors}}, path, acc) do
    msg = ["No match of any schema#{at_path(path)}"]

    errors =
      errors
      |> Enum.map(fn reason ->
        JsonXema.ValidationError.travers_errors(reason, [], &error_messages/3, path: path)
      end)
      |> Enum.reverse()
      |> indent()

    Enum.concat([errors, msg, acc])
  end

  defp error_messages(%{oneOf: {:ok, success}}, path, acc) do
    msg = "More as one schema matches (indexes: #{inspect(success)})"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{required: required}, path, acc) do
    msg = "Required properties are missing: #{inspect(required)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{propertyNames: errors, value: _value}, path, acc) do
    msg = ["Invalid property names#{at_path(path)}"]

    errors =
      errors
      |> Enum.map(fn {key, reason} ->
        "#{inspect(key)} : #{error_messages(reason, [], [])}"
      end)
      |> Enum.reverse()
      |> indent()

    Enum.concat([errors, msg, acc])
  end

  defp error_messages(%{dependencies: deps}, path, acc) do
    msg =
      deps
      |> Enum.reduce([], fn
        {key, reason}, acc when is_map(reason) ->
          sub_msg =
            reason
            |> error_messages(path, [])
            |> Enum.reverse()
            |> indent()
            |> Enum.join("\n")

          ["Dependencies for #{inspect(key)} failed#{at_path(path)}\n#{sub_msg}" | acc]

        {key, reason}, acc ->
          [
            "Dependencies for #{inspect(key)} failed#{at_path(path)}" <>
              " Missing required key #{inspect(reason)}."
            | acc
          ]
      end)
      |> Enum.reverse()
      |> Enum.join("\n")

    [msg | acc]
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
    msg = "Expected unique items, got #{inspect(value)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{const: const, value: value}, path, acc) do
    msg = "Expected #{inspect(const)}, got #{inspect(value)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{pattern: pattern, value: value}, path, acc) do
    msg = "Pattern #{inspect(pattern)} does not match value #{inspect(value)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{type: type, value: value}, path, acc) do
    msg = "Expected #{inspect(type)}, got #{inspect(value)}"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{type: false}, path, acc) do
    msg = "Schema always fails validation"
    [msg <> at_path(path) | acc]
  end

  defp error_messages(%{properties: _}, _path, acc), do: acc

  defp error_messages(%{items: _}, _path, acc), do: acc

  defp error_messages(_error, path, acc) do
    msg = "Unexpected error"
    [msg <> at_path(path) | acc]
  end

  defp at_path([]), do: "."

  defp at_path(path), do: ", at #{inspect(path)}."

  defp indent(list), do: Enum.map(list, fn str -> "  #{str}" end)
end
