defmodule AshJsonApi do
  @moduledoc """
  Introspection functions for `AshJsonApi` apis.

  For Api DSL documentation, see `AshJsonApi.Api`.

  For Resource DSL documentation, see `AshJsonApi.Resource`

  To get started, see the [getting started guide](/documentation/tutorials/getting-started-with-json-api.md)
  """

  @deprecated "See `AshJsonApi.Api.Info.prefix/1`"
  defdelegate prefix(api), to: AshJsonApi.Api.Info

  @deprecated "See `AshJsonApi.Api.Info.serve_schema?/1`"
  defdelegate serve_schema?(api), to: AshJsonApi.Api.Info

  @deprecated "See `AshJsonApi.Api.Info.authorize?/1`"
  defdelegate authorize?(api), to: AshJsonApi.Api.Info

  @deprecated "See `AshJsonApi.Api.Info.log_errors?/1`"
  defdelegate log_errors?(api), to: AshJsonApi.Api.Info

  @deprecated "See `AshJsonApi.Api.Info.router/1`"
  defdelegate router(api), to: AshJsonApi.Api.Info
end
