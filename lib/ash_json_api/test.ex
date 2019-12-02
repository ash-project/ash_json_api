defmodule AshJsonApi.Test do
  use Plug.Test
  import ExUnit.Assertions

  @schema "test/support/response_schema" |> File.read!() |> Jason.decode!() |> JsonXema.new()

  def get(api, path, opts \\ []) do
    result =
      :get
      |> conn(path)
      |> put_req_header("content-type", "application/json")
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
    result =
      :get
      |> conn(path, Jason.encode!(body))
      |> put_req_header("content-type", "application/json")
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
