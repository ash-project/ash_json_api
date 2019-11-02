defmodule AshJsonApi.JsonApi do
  defmacro json_api(do: body) do
    quote do
      import AshJsonApi.JsonApi.Routes, only: [routes: 1]
      import AshJsonApi.JsonApi, only: [fields: 1, include: 1, join_fields: 2]
      unquote(body)
      import AshJsonApi.JsonApi.Routes, only: []
    end
  end

  defmacro include(includes) do
    quote bind_quoted: [includes: includes] do
      @json_api_includes includes
    end
  end

  defmacro join_fields(association, fields) do
    quote bind_quoted: [association: association, fields: fields] do
      @json_api_join_fields {association, fields}
    end
  end

  defmacro fields(fields) do
    quote bind_quoted: [fields: fields] do
      # TODO: Validate presence of fields
      fields
      |> List.wrap()
      |> Enum.map(fn field ->
        @json_api_fields field
      end)
    end
  end
end
