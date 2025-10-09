# SPDX-FileCopyrightText: 2020 Zach Daniel
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Controllers.PostToRelationship do
  @moduledoc false
  alias AshJsonApi.Controllers.{Helpers, Response}
  alias AshJsonApi.Request

  def init(options) do
    # initialize options
    options
  end

  def call(conn, options) do
    action =
      options[:action] || Ash.Resource.Info.primary_action!(options[:resource], :update)

    domain = options[:domain]
    route = options[:route]
    all_domains = options[:all_domains]

    argument =
      action.arguments
      |> Enum.find(fn argument ->
        argument.name == options[:relationship]
      end)

    relationship =
      Enum.find_value(action.changes, fn
        %{change: {Ash.Resource.Change.ManageRelationship, opts}} ->
          opts[:argument] == argument.name && opts[:relationship] &&
            Ash.Resource.Info.relationship(options[:resource], opts[:relationship])

        _ ->
          nil
      end)

    if !relationship do
      raise "Resource #{inspect(options[:resource])} must have a `change manage_relationship` with relationship #{options[:relationship]} for route #{inspect(options[:route])}"
    end

    if !argument do
      raise "Action #{action.name} must have an argument #{options[:relationship].name} for route #{inspect(options[:route])}"
    end

    conn
    |> Request.from(options[:resource], action, domain, all_domains, route, options[:prefix])
    |> Helpers.fetch_record_from_path()
    |> Helpers.add_to_relationship(relationship.name)
    |> Helpers.fetch_metadata()
    |> Helpers.render_or_render_errors(conn, fn conn, request ->
      Response.render_many_relationship(conn, request, 200, relationship)
    end)
  end
end
