defmodule AshJsonApi.JsonSchema.Helpers do
  @spec build_filter_schema(map(), keyword()) :: map()
  def build_filter_schema(field_schema, opts \\ []) do
    nullable = Keyword.get(opts, :nullable, true)
    ordered = Keyword.get(opts, :ordered, false)

    properties = %{
      "equals" => field_schema,
      "not_equals" => field_schema,
      "eq" => field_schema,
      "not_eq" => field_schema
    }

    properties =
      if nullable,
        do:
          Map.merge(properties, %{
            "is_nil" => %{
              "type" => ["boolean", "string"],
              "match" => "^(true|false)$"
            }
          }),
        else: properties

    properties =
      if ordered,
        do:
          Map.merge(properties, %{
            "gt" => field_schema,
            "lt" => field_schema,
            "gte" => field_schema,
            "lte" => field_schema,
            "less_than" => field_schema,
            "greater_than" => field_schema,
            "less_than_or_equal" => field_schema,
            "greater_than_or_equal" => field_schema
          }),
        else: properties

    predicate_schema = %{"type" => "object", "properties" => properties}

    %{"oneOf" => [field_schema, predicate_schema]}
  end
end
