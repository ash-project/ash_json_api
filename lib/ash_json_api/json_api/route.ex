defmodule AshJsonApi.JsonApi.Route do
  defstruct [:route, :action, :relationship, :primary?]

  def new(opts) do
    %__MODULE__{
      route: opts[:route],
      action: opts[:action],
      primary?: opts[:primary?],
      relationship: opts[:relationship]
    }
  end
end
