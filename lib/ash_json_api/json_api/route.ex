defmodule AshJsonApi.JsonApi.Route do
  defstruct [:route, :prune, :action, :method, :fields, :controller, :relationship, :primary?]

  def new(opts) do
    # TODO: Right now we just skip straight to the action in general.
    %__MODULE__{
      route: opts[:route],
      prune: opts[:prune],
      action: opts[:action],
      primary?: opts[:primary?],
      method: opts[:method],
      controller: opts[:controller],
      relationship: opts[:relationship]
    }
  end
end
