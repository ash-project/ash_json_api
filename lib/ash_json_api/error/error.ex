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

  @callback new(Keyword.t()) :: %AshJsonApi.Error{} | list(%AshJsonApi.Error{})

  @type t :: %__MODULE__{}

  alias Ash.Error.{Forbidden, Framework, Invalid, Unknown}

  alias AshJsonApi.Error.FrameworkError

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

  def to_json_api_errors(domain, _resource, %{class: :invalid} = error, _type) do
    if AshJsonApi.ToJsonApiError.impl_for(error) do
      List.wrap(AshJsonApi.ToJsonApiError.to_json_api_error(error))
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
            detail: """
            Raised error: #{uuid}

            #{Exception.format(:error, error, stacktrace)}"
            """
          }
        ]
      end
    end
  end

  def to_json_api_errors(_resource, %{class: :forbidden} = error, _type) do
    [
      %__MODULE__{
        id: Ash.ErrorKind.id(error),
        status_code: class_to_status(error.class),
        code: "forbidden",
        title: "Forbidden",
        detail: "forbidden"
      }
    ]
  end

  def to_json_api_errors(_resource, error, _type) do
    [
      FrameworkError.new(internal_description: "something went wrong. #{inspect(error)}")
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
    format_log(FrameworkError.new([]))
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

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @detail Module.get_attribute(__MODULE__, :detail, opts[:detail]) ||
                raise("Must provide a detail for #{__MODULE__}")
      @title Module.get_attribute(__MODULE__, :title, opts[:title]) ||
               raise("Must provide a title for #{__MODULE__}")
      @status_code Module.get_attribute(__MODULE__, :status_code, opts[:status_code]) ||
                     raise("Must provide a status_code for #{__MODULE__}")
      @code Module.get_attribute(__MODULE__, :code, opts[:code]) ||
              String.trim_leading(inspect(__MODULE__), "AshJsonApi.Error.")

      @behaviour AshJsonApi.Error

      def new(opts) do
        [
          detail: @detail,
          title: @title,
          code: @code,
          status_code: @status_code,
          id: Ecto.UUID.generate()
        ]
        |> Keyword.merge(opts)
        |> Keyword.update!(:detail, &String.trim/1)
        |> Keyword.update!(:title, &String.trim/1)
        |> Keyword.update!(:code, fn code ->
          case opts[:code_suffix] do
            suffix when is_bitstring(suffix) ->
              code <> ":" <> suffix

            _ ->
              code
          end
        end)
        |> Keyword.delete(:code_suffix)
        |> AshJsonApi.Error.new()
      end

      defoverridable new: 1
    end
  end
end

defimpl AshJsonApi.ToJsonApiError, for: Ash.Error.Changes.InvalidChanges do
  def to_json_api_error(error) do
    %AshJsonApi.Error{
      id: Ash.UUID.generate(),
      status_code: AshJsonApi.Error.class_to_status(error.class),
      code: "invalid",
      title: "Invalid",
      source_parameter: to_string(error.field),
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
      source_parameter: to_string(error.field),
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
