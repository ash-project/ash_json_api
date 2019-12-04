defmodule AshJsonApi.Test do
  use Plug.Test
  import ExUnit.Assertions

  @external_resource "test/support/response_schema"
  @schema "test/support/response_schema" |> File.read!() |> Jason.decode!() |> JsonXema.new()

  def get(api, path, opts \\ []) do
    result =
      :get
      |> conn(path)
      |> put_req_header("content-type", "application/vnd.api+json")
      |> put_req_header("accept", "application/vnd.api+json")
      |> api.router().call(api.router().init([]))

    assert result.state == :sent

    if opts[:status] do
      assert result.status == opts[:status]
    end

    if Keyword.get(opts, :decode?, true) do
      resp_body = Jason.decode!(result.resp_body)

      JsonXema.validate!(@schema, resp_body)

      %{result | resp_body: Jason.decode!(result.resp_body)}
    else
      result
    end
  end

  def post(api, path, body, opts \\ []) do
    schema = AshJsonApi.JsonSchema.generate(api)
    full_path = Path.join(AshJsonApi.prefix(api) || "", path)

    endpoint_schema =
      Enum.find(schema, fn element ->
        match?(%{"method" => "POST", "href" => ^full_path}, element)
      end)

    unless endpoint_schema do
      raise "Invalid endpoint, no schema found for POST #{path}"
    end

    endpoint_schema
    |> JsonXema.new()
    |> JsonXema.validate!(body)

    result =
      :get
      |> conn(path, Jason.encode!(body))
      |> put_req_header("content-type", "application/vnd.api+json")
      |> put_req_header("accept", "application/vnd.api+json")
      |> api.router().call(api.router().init([]))

    assert result.state == :sent

    if opts[:status] do
      assert result.status == opts[:status]
    end

    if Keyword.get(opts, :decode?, true) do
      resp_body = Jason.decode!(result.resp_body)

      JsonXema.validate!(@schema, resp_body)
      %{result | resp_body: resp_body}
    else
      result
    end
  end

  def assert_data_equals(conn, expected_data) do
    assert %{"data" => ^expected_data} = conn.resp_body
  end
end
