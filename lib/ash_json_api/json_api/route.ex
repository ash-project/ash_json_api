defmodule AshJsonApi.JsonApi.Route do
  defstruct [
    :route,
    :prune,
    :action,
    :action_type,
    :method,
    :fields,
    :controller,
    :relationship,
    :paginate?,
    :primary?
  ]

  def new(opts) do
    # TODO: Right now we just skip straight to the action in general.
    %__MODULE__{
      route: opts[:route],
      prune: opts[:prune],
      action: opts[:action],
      action_type: opts[:action_type],
      primary?: opts[:primary?],
      method: opts[:method],
      paginate?: opts[:paginate?],
      controller: opts[:controller],
      relationship: opts[:relationship]
    }
  end
end
