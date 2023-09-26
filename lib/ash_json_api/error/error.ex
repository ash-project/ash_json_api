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

  def to_json_api_errors(resource, errors, type) when is_list(errors) do
    Enum.flat_map(errors, &to_json_api_errors(resource, &1, type))
  end

  def to_json_api_errors(resource, %Unknown{errors: errors} = unknown, type) do
    inner_errors = List.flatten(List.wrap(Map.get(unknown, :error)))
    to_json_api_errors(resource, inner_errors ++ errors, type)
  end

  def to_json_api_errors(resource, %mod{errors: errors}, type)
      when mod in [Forbidden, Framework, Invalid] do
    Enum.flat_map(errors, &to_json_api_errors(resource, &1, type))
  end

  def to_json_api_errors(_resource, %__MODULE__{} = error, _type) do
    [error]
  end

  def to_json_api_errors(resource, %{class: :invalid} = error, type)
      when type in [:create, :update] do
    case error do
      %{fields: fields} = error ->
        Enum.map(fields, fn field ->
          %__MODULE__{
            id: Ash.ErrorKind.id(error),
            status_code: class_to_status(error.class),
            code: Ash.ErrorKind.code(error),
            title: Ash.ErrorKind.code(error),
            detail: Ash.ErrorKind.message(error),
            source_pointer: source_pointer(resource, field, type)
          }
        end)

      %{field: field} = error ->
        [
          %__MODULE__{
            id: Ash.ErrorKind.id(error),
            status_code: class_to_status(error.class),
            code: Ash.ErrorKind.code(error),
            title: Ash.ErrorKind.code(error),
            detail: Ash.ErrorKind.message(error),
            source_pointer: source_pointer(resource, field, type)
          }
        ]

      error ->
        [
          %__MODULE__{
            id: Ash.ErrorKind.id(error),
            status_code: class_to_status(error.class),
            code: Ash.ErrorKind.code(error),
            title: Ash.ErrorKind.code(error),
            detail: Ash.ErrorKind.message(error)
          }
        ]
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

  defp source_pointer(resource, field, type) when type in [:create, :update] do
    cond do
      Ash.Resource.Info.public_attribute(resource, field) ->
        "/data/attributes/#{field}"

      Ash.Resource.Info.public_relationship(resource, field) ->
        "/data/relationships/#{field}"

      true ->
        :undefined
    end
  end

  defp source_pointer(_resource, _field, _type) do
    :undefined
  end

  defp class_to_status(:forbidden), do: 403
  defp class_to_status(:invalid), do: 400

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
