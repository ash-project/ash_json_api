defmodule AshJsonApi.Error do
  defstruct id: :undefined,
            about: :undefined,
            status: :undefined,
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

  def new(opts) do
    struct!(__MODULE__, opts)
  end

  def format_log(error) when is_bitstring(error) do
    format_log(AshJsonApi.Error.FrameworkError.new([]))
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
          status_code: @status_code
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
