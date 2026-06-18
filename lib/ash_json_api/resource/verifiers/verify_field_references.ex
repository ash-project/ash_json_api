# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Resource.Verifiers.VerifyFieldReferences do
  @moduledoc "Validates field names referenced in JSON:API DSL options"
  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl) do
    resource = Spark.Dsl.Verifier.get_persisted(dsl, :module)
    show_fields = AshJsonApi.Resource.Info.show_fields(dsl)
    hide_fields = AshJsonApi.Resource.Info.hide_fields(dsl)

    public_fields =
      dsl
      |> Ash.Resource.Info.public_attributes()
      |> Enum.concat(Ash.Resource.Info.public_relationships(dsl))
      |> Enum.concat(Ash.Resource.Info.public_calculations(dsl))
      |> Enum.concat(Ash.Resource.Info.public_aggregates(dsl))
      |> MapSet.new(& &1.name)

    validate_fields!(resource, :show_fields, show_fields, public_fields)
    validate_fields!(resource, :hide_fields, hide_fields, public_fields)
    validate_show_hide_overlap!(resource, show_fields, hide_fields)

    :ok
  end

  defp validate_fields!(_resource, _option, nil, _public_fields), do: :ok

  defp validate_fields!(resource, option, fields, public_fields) do
    Enum.each(fields, fn field ->
      unless MapSet.member?(public_fields, field) do
        raise Spark.Error.DslError,
          module: resource,
          path: [:json_api, option],
          message: """
          Unknown public field `#{inspect(field)}` in `#{option}`.

          Available: #{inspect(public_fields |> MapSet.to_list() |> Enum.sort())}
          """
      end
    end)
  end

  defp validate_show_hide_overlap!(_resource, nil, _hide_fields), do: :ok

  defp validate_show_hide_overlap!(resource, show_fields, hide_fields) do
    overlap =
      show_fields
      |> MapSet.new()
      |> MapSet.intersection(MapSet.new(hide_fields || []))
      |> MapSet.to_list()
      |> Enum.sort()

    unless Enum.empty?(overlap) do
      raise Spark.Error.DslError,
        module: resource,
        path: [:json_api],
        message: """
        Fields cannot appear in both `show_fields` and `hide_fields`.

        Conflicting fields: #{inspect(overlap)}
        """
    end
  end
end
