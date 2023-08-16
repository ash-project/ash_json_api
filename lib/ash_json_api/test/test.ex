defmodule AshJsonApi.Test do
  @moduledoc false
  use Plug.Test

  require ExUnit.Assertions
  import ExUnit.Assertions

  # This probably won't work for users of ashjsonapi
  @schema_file "lib/ash_json_api/test/response_schema"
  @external_resource @schema_file

  # @schema @schema_file |> File.read!() |> Jason.decode!() |> JsonXema.new()

  def get(api, path, opts \\ []) do
    result =
      :get
      |> conn(path)
      |> set_accept_request_header(opts)
      |> AshJsonApi.Api.Info.router(api).call(AshJsonApi.Api.Info.router(api).init([]))

    assert result.state == :sent

    unless opts[:skip_resp_header_check] do
      if 200 <= result.status and result.status <= 300 do
        assert_response_header_equals(result, "content-type", "application/vnd.api+json")
      end
    end

    if opts[:status] do
      assert result.status == opts[:status]
    end

    if Keyword.get(opts, :decode?, true) do
      %{result | resp_body: Jason.decode!(result.resp_body)}
    else
      result
    end
  end

  def post(api, path, body, opts \\ []) do
    result =
      :post
      |> conn(path, Jason.encode!(body))
      |> set_content_type_request_header(opts)
      |> set_accept_request_header(opts)
      |> AshJsonApi.Api.Info.router(api).call(AshJsonApi.Api.Info.router(api).init([]))

    assert result.state == :sent

    unless opts[:skip_resp_header_check] do
      if 200 <= result.status and result.status <= 300 do
        assert_response_header_equals(result, "content-type", "application/vnd.api+json")
      end
    end

    if opts[:status] do
      assert result.status == opts[:status]
    end

    if Keyword.get(opts, :decode?, true) do
      resp_body = Jason.decode!(result.resp_body)

      # JsonXema.validate!(@schema, resp_body)
      %{result | resp_body: resp_body}
    else
      result
    end
  end

  def patch(api, path, body, opts \\ []) do
    result =
      :patch
      |> conn(path, Jason.encode!(body))
      |> set_content_type_request_header(opts)
      |> set_accept_request_header(opts)
      |> AshJsonApi.Api.Info.router(api).call(AshJsonApi.Api.Info.router(api).init([]))

    assert result.state == :sent

    unless opts[:skip_resp_header_check] do
      if 200 <= result.status and result.status <= 300 do
        assert_response_header_equals(result, "content-type", "application/vnd.api+json")
      end
    end

    if opts[:status] do
      assert result.status == opts[:status]
    end

    if Keyword.get(opts, :decode?, true) do
      resp_body = Jason.decode!(result.resp_body)

      # JsonXema.validate!(@schema, resp_body)
      %{result | resp_body: resp_body}
    else
      result
    end
  end

  def delete(api, path, opts \\ []) do
    result =
      :delete
      |> conn(path)
      |> set_accept_request_header(opts)
      |> AshJsonApi.Api.Info.router(api).call(AshJsonApi.Api.Info.router(api).init([]))

    assert result.state == :sent

    unless opts[:skip_resp_header_check] do
      if 200 <= result.status and result.status <= 300 do
        assert_response_header_equals(result, "content-type", "application/vnd.api+json")
      end
    end

    if opts[:status] do
      assert result.status == opts[:status]
    end

    if Keyword.get(opts, :decode?, true) do
      %{result | resp_body: Jason.decode!(result.resp_body)}
    else
      result
    end
  end

  defmacro assert_data_equals(conn, expected_data) do
    quote bind_quoted: [conn: conn, expected_data: expected_data] do
      assert %{"data" => ^expected_data} = conn.resp_body
    end
  end

  def assert_response_header_equals(conn, header, value) do
    assert get_resp_header(conn, header) == [value]
  end

  defmacro assert_attribute_equals(conn, attribute, expected_value) do
    quote bind_quoted: [attribute: attribute, expected_value: expected_value, conn: conn] do
      assert %{"data" => %{"attributes" => %{^attribute => ^expected_value}}} = conn.resp_body

      conn
    end
  end

  defmacro assert_id_equals(conn, expected_value) do
    quote bind_quoted: [expected_value: expected_value, conn: conn] do
      assert %{"data" => %{"id" => ^expected_value}} = conn.resp_body

      conn
    end
  end

  @doc """
  Validate the response contains a Resource Object as per 5.2 Specification 1.0

  A resource object MUST contain at least the following top-level members:
  - id
  - type

  see: https://jsonapi.org/format/1.0/#document-resource-objects
  """
  defmacro assert_valid_resource_object(conn, expected_type, expected_id) do
    quote bind_quoted: [conn: conn, expected_type: expected_type, expected_id: expected_id] do
      assert %{
               "data" => %{
                 "type" => ^expected_type,
                 "id" => ^expected_id
               }
             } = conn.resp_body

      conn
    end
  end

  defmacro assert_valid_resource_objects(conn, expected_type, expected_ids) do
    quote bind_quoted: [conn: conn, expected_type: expected_type, expected_ids: expected_ids] do
      assert %{
               "data" => results
             } = conn.resp_body

      assert Enum.all?(results, fn
               %{"type" => ^expected_type, "id" => maybe_known_id} ->
                 Enum.member?(expected_ids, maybe_known_id)

               _ ->
                 false
             end)

      conn
    end
  end

  defmacro assert_attribute_missing(conn, attribute) do
    quote bind_quoted: [conn: conn, attribute: attribute] do
      assert %{"data" => %{"attributes" => attributes}} = conn.resp_body

      refute Map.has_key?(attributes, attribute)
    end
  end

  defmacro assert_has_error(conn, fields) do
    quote do
      assert %{"errors" => [_ | _] = errors} = unquote(conn).resp_body

      assert Enum.any?(errors, fn error ->
               Enum.all?(unquote(fields), fn {key, val} ->
                 Map.get(error, key) == val
               end)
             end)
    end
  end

  defmacro assert_has_matching_include(conn, function) do
    quote do
      assert %{"included" => included} = unquote(conn).resp_body
      assert is_list(included)

      assert Enum.any?(included, fn included ->
               unquote(function).(included)
             end)
    end
  end

  # defmacro assert_has_keyset_pagination_links(conn, function) do
  #   quote do
  #     assert %{"links" => links} = unquote(conn).resp_body

  #     assert links = %{
  #     		"self": "http://example.com/articles?page[number]=3&page[size]=1",
  #         "first": "http://example.com/articles?page[number]=1&page[size]=1",
  #         "prev": "http://example.com/articles?page[number]=2&page[size]=1",
  #         "next": "http://example.com/articles?page[number]=4&page[size]=1",
  #         "last": "http://example.com/articles?page[number]=13&page[size]=1"
  #     }
  #   end
  # end

  defp set_content_type_request_header(conn, opts) do
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
    cond do
      opts[:exclude_req_accept_header] ->
        conn

      opts[:req_accept_header] ->
        conn
        |> put_req_header("accept", opts[:req_accept_header])

      true ->
        conn
        |> put_req_header("accept", "application/vnd.api+json")
    end
  end
end
