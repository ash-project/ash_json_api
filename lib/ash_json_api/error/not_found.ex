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
    filter = Keyword.fetch(opts, :filter)
    resource = Keyword.fetch(opts, :resource)

    case {filter, resource} do
      {{:ok, id}, {:ok, resource}} ->
        "No record of #{AshJsonApi.Resource.type(resource)} with id: #{inspect(id)}"

      {{:ok, id}, _} ->
        "No record with id: #{inspect(id)}"

      {_, {:ok, resource}} ->
        "No #{resource} record with id: #{inspect(filter)}"

      _ ->
        "No record found."
    end
  end
end
