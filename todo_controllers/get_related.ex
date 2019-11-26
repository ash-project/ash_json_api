defmodule AshJsonApi.Controllers.GetRelated do
  def init(options) do
    # initialize options
    options
  end

  def call(conn, options) do
    relationship = options[:relationship]

    case relationship do
      %{type: :belongs_to} ->
        AshJsonApi.Controllers.GetBelongsTo.call(conn, options)

      %{type: :has_one} ->
        AshJsonApi.Controllers.GetHasOne.call(conn, options)

      %{type: :has_many} ->
        AshJsonApi.Controllers.GetHasMany.call(conn, options)

      %{type: :many_to_many} ->
        AshJsonApi.Controllers.GetManyToMany.call(conn, options)
    end
  end
end
