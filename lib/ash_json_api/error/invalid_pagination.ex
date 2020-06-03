defmodule AshJsonApi.Error.InvalidPagination do
  @moduledoc """
  Returned when one of the nested parameters provided in the query parameter `page`
  is invalid
  """
  @detail @moduledoc
  @title "Invalid Pagination Parameter"
  @status_code 400

  use AshJsonApi.Error
end
