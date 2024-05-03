defmodule AshJsonApi do
  @moduledoc """
  Introspection functions for `AshJsonApi` domains.

  For domain DSL documentation, see `AshJsonApi.Domain`.

  For Resource DSL documentation, see `AshJsonApi.Resource`

  To get started, see the [getting started guide](/documentation/tutorials/getting-started-with-ash-json-api.md)
  """

  @deprecated "See `AshJsonApi.Domain.Info.prefix/1`"
  defdelegate prefix(domain), to: AshJsonApi.Domain.Info

  @deprecated "See `AshJsonApi.Domain.Info.serve_schema?/1`"
  defdelegate serve_schema?(domain), to: AshJsonApi.Domain.Info

  @deprecated "See `AshJsonApi.Domain.Info.authorize?/1`"
  defdelegate authorize?(domain), to: AshJsonApi.Domain.Info

  @deprecated "See `AshJsonApi.Domain.Info.log_errors?/1`"
  defdelegate log_errors?(domain), to: AshJsonApi.Domain.Info

  @deprecated "See `AshJsonApi.Domain.Info.router/1`"
  defdelegate router(domain), to: AshJsonApi.Domain.Info
end
