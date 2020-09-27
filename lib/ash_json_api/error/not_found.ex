defmodule AshJsonApi.Error.NotFound do
  @moduledoc """
  Returned when a record was explicitly requested, but could not be found.
  """
  @detail @moduledoc
  @title "Entity Not Found"
  @status_code 404

  use AshJsonApi.Error

  def new(opts) do
    opts
    |> Keyword.put(:detail, detail(opts))
    |> Keyword.put(:log_level, :info)
    |> Keyword.drop([:filter, :resource])
    |> super()
  end

  defp detail(opts) do
    filter = Keyword.get(opts, :filter)
    resource = Keyword.get(opts, :resource)

    if is_map(filter) || Keyword.keyword?(filter) do
      filter =
        Enum.map_join(filter, ", ", fn {key, value} ->
          try do
            "#{key}: #{to_string(value)}"
          rescue
            _ ->
              "#{key}: #{inspect(value)}"
          end
        end)

      "No #{AshJsonApi.Resource.type(resource)} record found with `#{filter}`"
    else
      "No #{AshJsonApi.Resource.type(resource)} record found with `#{inspect(filter)}`"
    end
  end
end
