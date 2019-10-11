defmodule AshJsonApi.Error.InvalidInclude do
  defstruct includes: []

  @behaviour Ash.Error

  @type t :: %__MODULE__{}

  def new(opts) do
    %__MODULE__{includes: opts[:invalid_includes] || []}
  end
end
