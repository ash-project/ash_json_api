defmodule AshJsonApi.Error do
  @moduledoc "Represents an AshJsonApi Error"
  defstruct id: :undefined,
            about: :undefined,
            code: :undefined,
            title: :undefined,
            detail: :undefined,
            source_pointer: :undefined,
            source_parameter: :undefined,
            meta: :undefined,
            status_code: :undefined,
            internal_description: nil,
            log_level: :error

  @type t :: %__MODULE__{}

  alias Ash.Error.{Forbidden, Framework, Invalid, Unknown}

  require Logger

  def to_json_api_errors(domain, resource, errors, type) when is_list(errors) do
    Enum.flat_map(errors, &to_json_api_errors(domain, resource, &1, type))
  end

  def to_json_api_errors(domain, resource, %mod{errors: errors}, type)
      when mod in [Forbidden, Framework, Invalid, Unknown] do
    Enum.flat_map(errors, &to_json_api_errors(domain, resource, &1, type))
  end

  def to_json_api_errors(_domain, _resource, %__MODULE__{} = error, _type) do
    [error]
  end

  def to_json_api_errors(domain, resource, %{class: :invalid} = error, type) do
    if AshJsonApi.ToJsonApiError.impl_for(error) do
      error
      |> AshJsonApi.ToJsonApiError.to_json_api_error()
      |> List.wrap()
      |> Enum.flat_map(&with_source_pointer(&1, error, resource, type))
    else
      uuid = Ash.UUID.generate()

      stacktrace =
        case error do
          %{stacktrace: %{stacktrace: v}} ->
            v

          _ ->
            nil
        end

      Logger.warning(
        "`#{uuid}`: AshJsonApi.Error not implemented for error:\n\n#{Exception.format(:error, error, stacktrace)}"
      )

      if AshJsonApi.Domain.Info.show_raised_errors?(domain) do
        [
          %__MODULE__{
            id: uuid,
            status_code: class_to_status(error.class),
            code: "something_went_wrong",
            title: "SomethingWentWrong",
            detail: """
            Raised error: #{uuid}

            #{Exception.format(:error, error, stacktrace)}"
            """
          }
        ]
      else
        [
          %__MODULE__{
            id: uuid,
            status_code: class_to_status(error.class),
            code: "something_went_wrong",
            title: "SomethingWentWrong",
            detail: "Something went wrong. Error id: #{uuid}"
          }
        ]
      end
    end
  end

  def to_json_api_errors(_domain, _resource, %{class: :forbidden} = error, _type) do
    [
      %__MODULE__{
        id: Ash.UUID.generate(),
        status_code: class_to_status(error.class),
        code: "forbidden",
        title: "Forbidden",
        detail: "forbidden"
      }
    ]
  end

  def to_json_api_errors(_domain, _resource, error, _type) do
    [
      Ash.Error.Unknown.exception(error: error)
    ]
  end

  @doc "Turns an error class into an HTTP status code"
  def class_to_status(:forbidden), do: 403
  def class_to_status(:invalid), do: 400
  def class_to_status(_), do: 500

  def new(opts) do
    struct(__MODULE__, opts)
  end

  def format_log(error) when is_bitstring(error) do
    format_log(Ash.Error.Framework.exception([]))
  end

  def format_log(error) do
    code =
      if is_bitstring(error.code) do
        [error.code, ": "]
      else
        ""
      end

    title =
      if is_bitstring(error.title) do
        error.title
      else
        "Unknown Error"
      end

    description =
      cond do
        is_bitstring(error.internal_description) ->
          error.internal_description

        is_bitstring(error.detail) ->
          error.detail

        true ->
          "No description"
      end

    [code, title, " | ", description]
  end

  def with_source_pointer(%{source_pointer: source_pointer} = built_error, _, _, _)
      when source_pointer not in [nil, :undefined] do
    [built_error]
  end

  def with_source_pointer(built_error, %{fields: fields, path: path}, resource, type)
      when is_list(fields) and fields != [] do
    Enum.map(fields, fn field ->
      %{built_error | source_pointer: source_pointer(resource, field, path, type)}
    end)
  end

  def with_source_pointer(built_error, %{field: field, path: path}, resource, type)
      when not is_nil(field) do
    [
      %{built_error | source_pointer: source_pointer(resource, field, path, type)}
    ]
  end

  def with_source_pointer(built_error, _, _resource, _type) do
    [built_error]
  end

  defp source_pointer(_resource, field, path, :action) do
    "/data/attributes/#{Enum.join(List.wrap(path) ++ [field], "/")}"
  end

  defp source_pointer(resource, field, path, type)
       when type in [:create, :update] and not is_nil(field) do
    if path == [] && Ash.Resource.Info.public_relationship(resource, field) do
      "/data/relationships/#{field}"
    else
      "/data/attributes/#{Enum.join(List.wrap(path) ++ [field], "/")}"
    end
  end

  defp source_pointer(_resource, _field, _path, _) do
    :undefined
  end
end

defimpl AshJsonApi.ToJsonApiError, for: Ash.Error.Changes.InvalidChanges do
  def to_json_api_error(error) do
    %AshJsonApi.Error{
      id: Ash.UUID.generate(),
      status_code: AshJsonApi.Error.class_to_status(error.class),
      code: "invalid",
      title: "Invalid",
      detail: error.message,
      meta: Map.new(error.vars)
    }
  end
end

defimpl AshJsonApi.ToJsonApiError, for: Ash.Error.Query.InvalidQuery do
  def to_json_api_error(error) do
    %AshJsonApi.Error{
      id: Ash.UUID.generate(),
      status_code: AshJsonApi.Error.class_to_status(error.class),
      code: "invalid_query",
      title: "InvalidQuery",
      detail: error.message,
      meta: Map.new(error.vars)
    }
  end
end

defimpl AshJsonApi.ToJsonApiError, for: Ash.Error.Page.InvalidKeyset do
  def to_json_api_error(error) do
    %AshJsonApi.Error{
      id: Ash.UUID.generate(),
      status_code: AshJsonApi.Error.class_to_status(error.class),
      code: "invalid_keyset",
      title: "InvalidKeyset",
      detail: error.message,
      meta: Map.new(error.vars)
    }
  end
end

defimpl AshJsonApi.ToJsonApiError, for: Ash.Error.Changes.InvalidAttribute do
  def to_json_api_error(error) do
    %AshJsonApi.Error{
      id: Ash.UUID.generate(),
      status_code: AshJsonApi.Error.class_to_status(error.class),
      code: "invalid_attribute",
      title: "InvalidAttribute",
      detail: error.message,
      meta: Map.new(error.vars)
    }
  end
end

defimpl AshJsonApi.ToJsonApiError, for: Ash.Error.Changes.InvalidArgument do
  def to_json_api_error(error) do
    %AshJsonApi.Error{
      id: Ash.UUID.generate(),
      status_code: AshJsonApi.Error.class_to_status(error.class),
      code: "invalid_argument",
      title: "InvalidArgument",
      detail: error.message,
      meta: Map.new(error.vars)
    }
  end
end

defimpl AshJsonApi.ToJsonApiError, for: Ash.Error.Query.InvalidArgument do
  def to_json_api_error(error) do
    %AshJsonApi.Error{
      id: Ash.UUID.generate(),
      status_code: AshJsonApi.Error.class_to_status(error.class),
      code: "invalid_argument",
      title: "InvalidArgument",
      detail: error.message,
      meta: Map.new(error.vars)
    }
  end
end

defimpl AshJsonApi.ToJsonApiError, for: Ash.Error.Action.InvalidArgument do
  def to_json_api_error(error) do
    %AshJsonApi.Error{
      id: Ash.UUID.generate(),
      status_code: AshJsonApi.Error.class_to_status(error.class),
      code: "invalid_argument",
      title: "InvalidArgument",
      detail: error.message,
      meta: Map.new(error.vars)
    }
  end
end

defimpl AshJsonApi.ToJsonApiError, for: Ash.Error.Changes.Required do
  def to_json_api_error(error) do
    %AshJsonApi.Error{
      id: Ash.UUID.generate(),
      status_code: AshJsonApi.Error.class_to_status(error.class),
      code: "required",
      title: "Required",
      detail: "is required",
      meta: Map.new(error.vars)
    }
  end
end

defimpl AshJsonApi.ToJsonApiError, for: Ash.Error.Query.NotFound do
  def to_json_api_error(error) do
    %AshJsonApi.Error{
      id: Ash.UUID.generate(),
      status_code: AshJsonApi.Error.class_to_status(error.class),
      code: "not_found",
      title: "NotFound",
      detail: "could not be found",
      meta: Map.new(error.vars)
    }
  end
end

defimpl AshJsonApi.ToJsonApiError, for: Ash.Error.Query.Required do
  def to_json_api_error(error) do
    %AshJsonApi.Error{
      id: Ash.UUID.generate(),
      status_code: AshJsonApi.Error.class_to_status(error.class),
      code: "required",
      title: "Required",
      detail: "is required",
      meta: Map.new(error.vars)
    }
  end
end

defimpl AshJsonApi.ToJsonApiError, for: Ash.Error.Forbidden.Policy do
  def to_json_api_error(error) do
    message =
      if Application.get_env(:ash_json_api, :policies)[:show_policy_breakdowns?] ||
           false do
        Ash.Error.Forbidden.Policy.report(error, help_text?: false)
      else
        "forbidden"
      end

    %AshJsonApi.Error{
      id: Ash.UUID.generate(),
      status_code: AshJsonApi.Error.class_to_status(error.class),
      code: "forbidden",
      title: "Forbidden",
      detail: message,
      meta: %{}
    }
  end
end

defimpl AshJsonApi.ToJsonApiError, for: Ash.Error.Forbidden.ForbiddenField do
  def to_json_api_error(error) do
    %AshJsonApi.Error{
      id: Ash.UUID.generate(),
      status_code: AshJsonApi.Error.class_to_status(error.class),
      code: "forbidden",
      title: "Forbidden",
      detail: "forbidden",
      meta: %{}
    }
  end
end

defimpl AshJsonApi.ToJsonApiError, for: Ash.Error.Invalid.InvalidPrimaryKey do
  def to_json_api_error(error) do
    %AshJsonApi.Error{
      id: Ash.UUID.generate(),
      status_code: AshJsonApi.Error.class_to_status(error.class),
      code: "invalid_primary_key",
      title: "InvalidPrimaryKey",
      detail: "invalid primary key provided",
      meta: Map.new(error.vars)
    }
  end
end

defimpl AshJsonApi.ToJsonApiError, for: Ash.Error.Invalid.NoSuchInput do
  def to_json_api_error(error) do
    %AshJsonApi.Error{
      id: Ash.UUID.generate(),
      status_code: 422,
      code: "no_such_input",
      title: "NoSuchInput",
      detail: Ash.Error.Invalid.NoSuchInput.message(error),
      meta: Map.new(error.vars)
    }
  end
end
