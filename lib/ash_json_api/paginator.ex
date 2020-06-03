defmodule AshJsonApi.Paginator do
  @moduledoc false
  defstruct [:limit, :results, :total, offset: 0]
end
