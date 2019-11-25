defmodule AshJsonApi.Error.NotFound do
  @detail """
  Returned when a record was explicitly requested, but could not be found.
  """
  @title "Entity Not Found"
  @status_code 404

  use AshJsonApi.Error

  def new(opts) do
    opts
    |> Keyword.put(:detail, detail(opts))
    |> Keyword.drop([:id, :resource])
    |> super()
  end

  defp detail(opts) do
    id = Keyword.fetch(opts, :id)
    resource = Keyword.fetch(opts, :resource)

    case {id, resource} do
      {{:ok, id}, {:ok, resource}} ->
        "No record of #{Ash.type(resource)} with id: #{id}"

      {{:ok, id}, _} ->
        "No record with id: #{id}"

      {_, {:ok, resource}} ->
        "No record with id: #{id}"

      _ ->
        "No record found."
    end
  end
end
