defmodule AshJsonApi.Error.InvalidPagination do
  @detail """
  Returned when one of the nested parameters provided in the query parameter `page`
  is invalid
  """
  @title "Invalid Pagination Parameter"
  @status_code 400

  use AshJsonApi.Error
end
