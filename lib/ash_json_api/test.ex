defmodule AshJsonApi.Test do
  use Plug.Test
  import ExUnit.Assertions

  @external_resource "test/support/response_schema"
  @schema "test/support/response_schema" |> File.read!() |> Jason.decode!() |> JsonXema.new()

  def get(api, path, opts \\ []) do
    result =
      :get
      |> conn(path)
      |> set_content_type_request_header(opts)
      |> set_accept_request_header(opts)
      |> api.router().call(api.router().init([]))

    assert result.state == :sent

    if opts[:resp_headers_include] do
      assert Enum.member?(result.resp_headers, opts[:resp_headers_include])
    end

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

  defp set_content_type_request_header(conn, opts) do
    # TODO: Content-Type is in capital case on the JSON:API spec, but elixir recommends we use lower case...
    cond do
      opts[:exclude_req_content_type_header] ->
        conn
      opts[:req_content_type_header] ->
        conn
        |> put_req_header("content-type", opts[:req_content_type_header])
      true ->
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
    end
  end

  defp set_accept_request_header(conn, opts) do
    if opts[:req_accept_header] do
     IO.inspect("Accept - I exist!!!!!!!")
     conn
     |> put_req_header("accept", "application/vnd.api+json")
    else
      conn
      |> put_req_header("accept", "application/vnd.api+json")
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

  @spec assert_data_equals(atom | %{resp_body: map}, any) :: map
  def assert_data_equals(conn, expected_data) do
    assert %{"data" => ^expected_data} = conn.resp_body
  end

  def assert_attribute_equals(conn, attribute, expected_value) do
    assert %{"data" => %{"attributes" => %{^attribute => ^expected_value}}} = conn.resp_body
  end

  def assert_attribute_missing(conn, attribute) do
    assert %{"data" => %{"attributes" => attributes}} = conn.resp_body

    refute Map.has_key?(attributes, attribute)
  end

  def assert_has_error(conn, fields) do
    assert %{"errors" => [_ | _] = errors} = conn.resp_body

    assert Enum.any?(errors, fn error ->
             Enum.all?(fields, fn {key, val} ->
               Map.get(error, key) == val
             end)
           end)
  end
end
