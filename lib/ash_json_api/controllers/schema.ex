defmodule AshJsonApi.Controllers.Schema do
  @moduledoc false
  def init(options) do
    options
  end

  # sobelow_skip ["XSS.SendResp"]
  def call(conn, opts) do
    api = opts[:api]
    format = Keyword.get(opts, :format, :json_schema)

    schema_doc =
      case format do
        :json_schema -> AshJsonApi.JsonSchema.generate(api)
        :open_api -> AshJsonApi.OpenApiSchema.generate(api)
      end

    schema = Jason.encode!(schema_doc)

    conn
    |> Plug.Conn.send_resp(200, schema)
    |> Plug.Conn.halt()
  end
end
