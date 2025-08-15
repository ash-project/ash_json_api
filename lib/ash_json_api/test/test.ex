defmodule AshJsonApi.Test do
  @moduledoc """
  Utilities for testing AshJsonApi.

  ## Making Requests

  The request testing functions get/patch/post/delete all support the following options

  - `:status`: Asserts that the response has the provided status after making the request
  - `:router`: The corresponding JsonApiRouter to go through. Can be set statically in config, see below for more.
  - `:actor`: Sets the provided actor as the actor for the request
  - `:tenant`: Sets the provided tenant as the tenant for the request
  - `:conn`: A conn to use, or a function that will modify the conn. If not provided, a default conn is used.

  A standard test would look like this:

  ```elixir
  test "can list posts", %{current_user: current_user} do
    Domain
    # GET /posts
    # assert resp.status == 200
    |> get("/posts", status: 200, actor: current_user, router: MyAppWeb.JsonApiRouter)
    # pattern match on the data key of the response
    |> assert_data_matches([
      %{
        "attributes" => %{
          "name" => "foo"
        }
      }
    ])
  end
  ```
  """
  import Plug.Test, except: [conn: 4, conn: 3]
  import Plug.Conn

  require ExUnit.Assertions
  import ExUnit.Assertions

  defp conn(method, path, opts) do
    conn(method, path, nil, opts)
  end

  defp conn(method, path, body, opts) do
    case opts[:conn] do
      fun when is_function(fun) ->
        Plug.Test.conn(method, path, body)
        |> fun.()

      nil ->
        Plug.Test.conn(method, path, body)

      conn ->
        conn
    end
  end

  @doc """
  Sends a GET request to the given path. See the module docs for more.
  """
  def get(domain, path, opts \\ []) do
    result =
      :get
      |> conn(path, opts)
      |> set_req_headers(opts)
      |> set_context_opts(opts)
      |> maybe_set_endpoint(opts)
      |> set_accept_request_header(opts)
      |> call_router(domain, opts)

    assert result.state == :sent

    unless opts[:skip_resp_header_check] do
      if 200 <= result.status and result.status <= 300 do
        assert_response_header_equals(result, "content-type", "application/vnd.api+json")
      end
    end

    if opts[:status] do
      resp_body =
        try do
          inspect(Jason.decode!(result.resp_body), pretty: true)
        rescue
          _ ->
            inspect(result.resp_body)
        end

      assert result.status == opts[:status], """
      Expected to get status #{opts[:status]} but got #{result.status}.

      Response body: #{resp_body}
      """
    end

    if Keyword.get(opts, :decode?, true) do
      %{result | resp_body: Jason.decode!(result.resp_body)}
    else
      result
    end
  end

  @doc """
  Sends a POST request to the given path. See the module docs for more.
  """
  def post(domain, path, body, opts \\ []) do
    result =
      :post
      |> conn(path, Jason.encode!(body), opts)
      |> set_req_headers(opts)
      |> set_context_opts(opts)
      |> set_content_type_request_header(opts)
      |> set_accept_request_header(opts)
      |> call_router(domain, opts)

    assert result.state == :sent

    unless opts[:skip_resp_header_check] do
      if 200 <= result.status and result.status <= 300 do
        assert_response_header_equals(result, "content-type", "application/vnd.api+json")
      end
    end

    if opts[:status] do
      resp_body =
        try do
          inspect(Jason.decode!(result.resp_body), pretty: true)
        rescue
          _ ->
            inspect(result.resp_body)
        end

      assert result.status == opts[:status], """
      Expected to get status #{opts[:status]} but got #{result.status}.

      Response body: #{resp_body}
      """
    end

    if Keyword.get(opts, :decode?, true) do
      resp_body = Jason.decode!(result.resp_body)

      # JsonXema.validate!(@schema, resp_body)
      %{result | resp_body: resp_body}
    else
      result
    end
  end

  if Code.ensure_loaded?(Multipart) do
    @doc """
    Sends a multipart POST request to the given path. See the module docs for more.
    """
    def multipart_post(domain, path, body, opts \\ []) do
      parser_opts =
        Plug.Parsers.init(parsers: [AshJsonApi.Plug.Parser], pass: ["*/*"], json_decoder: Jason)

      result =
        :post
        |> conn(path, Multipart.body_binary(body), opts)
        |> set_req_headers(opts)
        |> set_context_opts(opts)
        |> put_req_header(
          "content-type",
          Multipart.content_type(body, "multipart/x.ash+form-data")
        )
        |> set_accept_request_header(opts)
        |> Plug.Parsers.call(parser_opts)
        |> call_router(domain, opts)

      assert result.state == :sent

      unless opts[:skip_resp_header_check] do
        if 200 <= result.status and result.status <= 300 do
          assert_response_header_equals(result, "content-type", "application/vnd.api+json")
        end
      end

      if opts[:status] do
        resp_body =
          try do
            inspect(Jason.decode!(result.resp_body), pretty: true)
          rescue
            _ ->
              inspect(result.resp_body)
          end

        assert result.status == opts[:status], """
        Expected to get status #{opts[:status]} but got #{result.status}.

        Response body: #{resp_body}
        """
      end

      if Keyword.get(opts, :decode?, true) do
        resp_body = Jason.decode!(result.resp_body)

        # JsonXema.validate!(@schema, resp_body)
        %{result | resp_body: resp_body}
      else
        result
      end
    end
  else
    def multipart_post(_domain, _path, _body, _opts \\ []) do
      raise """
      Must add `:multipart` to your dependencies to test multipart posts.

      `{:multipart, "~> 0.4.0", only: [:dev, :test]}`

      Then run `mix deps.compile ash_json_api --force`
      """
    end
  end

  @doc """
  Sends a PATCH request to the given path. See the module docs for more.
  """
  def patch(domain, path, body, opts \\ []) do
    result =
      :patch
      |> conn(path, Jason.encode!(body), opts)
      |> set_req_headers(opts)
      |> set_context_opts(opts)
      |> set_content_type_request_header(opts)
      |> set_accept_request_header(opts)
      |> call_router(domain, opts)

    assert result.state == :sent

    unless opts[:skip_resp_header_check] do
      if 200 <= result.status and result.status <= 300 do
        assert_response_header_equals(result, "content-type", "application/vnd.api+json")
      end
    end

    if opts[:status] do
      resp_body =
        try do
          inspect(Jason.decode!(result.resp_body), pretty: true)
        rescue
          _ ->
            inspect(result.resp_body)
        end

      assert result.status == opts[:status], """
      Expected to get status #{opts[:status]} but got #{result.status}.

      Response body: #{resp_body}
      """
    end

    if Keyword.get(opts, :decode?, true) do
      resp_body = Jason.decode!(result.resp_body)

      # JsonXema.validate!(@schema, resp_body)
      %{result | resp_body: resp_body}
    else
      result
    end
  end

  @doc """
  Sends a DELETE request to the given path. See the module docs for more.
  """
  def delete(domain, path, opts \\ []) do
    result =
      :delete
      |> conn(path, opts)
      |> set_req_headers(opts)
      |> set_context_opts(opts)
      |> set_accept_request_header(opts)
      |> call_router(domain, opts)

    assert result.state == :sent

    unless opts[:skip_resp_header_check] do
      if 200 <= result.status and result.status <= 300 do
        assert_response_header_equals(result, "content-type", "application/vnd.api+json")
      end
    end

    if opts[:status] do
      resp_body =
        try do
          inspect(Jason.decode!(result.resp_body), pretty: true)
        rescue
          _ ->
            inspect(result.resp_body)
        end

      assert result.status == opts[:status], """
      Expected to get status #{opts[:status]} but got #{result.status}.

      Response body: #{resp_body}
      """
    end

    if Keyword.get(opts, :decode?, true) do
      %{result | resp_body: Jason.decode!(result.resp_body)}
    else
      result
    end
  end

  @doc """
  Assert that the response body's `"data"` equals an exact value
  """
  defmacro assert_data_equals(conn, expected_data) do
    quote do
      conn = unquote(conn)
      assert %{"data" => data} = conn.resp_body
      assert data == unquote(expected_data)

      conn
    end
  end

  @doc """
  Assert that the response body's `"data"` matches a pattern
  """
  defmacro assert_data_matches(conn, data_pattern) do
    quote do
      conn = unquote(conn)
      assert %{"data" => unquote(data_pattern)} = conn.resp_body

      conn
    end
  end

  @doc false
  defmacro assert_meta_equals(conn, expected_meta) do
    quote bind_quoted: [conn: conn, expected_meta: expected_meta] do
      assert %{"meta" => ^expected_meta} = conn.resp_body

      conn
    end
  end

  @doc false
  def assert_response_header_equals(conn, header, value) do
    assert get_resp_header(conn, header) == [value]
    conn
  end

  @doc false
  defmacro assert_attribute_equals(conn, attribute, expected_value) do
    quote bind_quoted: [attribute: attribute, expected_value: expected_value, conn: conn] do
      assert %{"data" => %{"attributes" => %{^attribute => ^expected_value}}} = conn.resp_body

      conn
    end
  end

  @doc false
  defmacro assert_id_equals(conn, expected_value) do
    quote bind_quoted: [expected_value: expected_value, conn: conn] do
      assert %{"data" => %{"id" => ^expected_value}} = conn.resp_body

      conn
    end
  end

  @doc false
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

  @doc false
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

  @doc false
  defmacro assert_invalid_resource_objects(conn, expected_type, expected_ids) do
    quote bind_quoted: [conn: conn, expected_type: expected_type, expected_ids: expected_ids] do
      assert %{
               "data" => results
             } = conn.resp_body

      assert not Enum.any?(results, fn
               %{"type" => ^expected_type, "id" => maybe_known_id} ->
                 Enum.member?(expected_ids, maybe_known_id)

               _ ->
                 false
             end)

      conn
    end
  end

  @doc false
  defmacro assert_attribute_missing(conn, attribute) do
    quote bind_quoted: [conn: conn, attribute: attribute] do
      assert %{"data" => %{"attributes" => attributes}} = conn.resp_body

      refute Map.has_key?(attributes, attribute)

      conn
    end
  end

  @doc """
  Asserts that an error is in the response where each key present in the provided map
  has the same value in the error.

  ## Example

  ```elixir
  Domain
  |> delete("/posts/1", status: 404)
  |> assert_has_error(%{
    "code" => "not_found",
    "detail" => "No post record found with `id: 1`",
    "title" => "Entity Not Found"
  })
  ```
  """
  defmacro assert_has_error(conn, fields) do
    quote do
      assert %{"errors" => [_ | _] = errors} = unquote(conn).resp_body

      assert Enum.any?(errors, fn error ->
               Enum.all?(unquote(fields), fn {key, val} ->
                 Map.get(error, key) == val
               end)
             end)

      unquote(conn)
    end
  end

  @doc """
  Assert that the given function returns true for at least one included record

  ## Example

  ```elixir
  Domain
  |> get("/posts/\#{post.id}/?include=author", status: 200)
  |> assert_has_matching_include(fn
    %{"type" => "author", "id" => ^author_id} ->
      true

    _ ->
      false
  end)
  ```
  """
  defmacro assert_has_matching_include(conn, function) do
    quote do
      assert %{"included" => included} = unquote(conn).resp_body
      assert is_list(included)

      assert Enum.any?(included, fn included ->
               unquote(function).(included)
             end)

      unquote(conn)
    end
  end

  @doc """
  Refute that the given function returns true for at least one included record

  ## Example

  ```elixir
  Domain
  |> get("/posts/\#{post.id}/?include=author", status: 200)
  |> refute_has_matching_include(fn
    %{"type" => "author", "id" => ^author_id} ->
      true

    _ ->
      false
  end)
  ```
  """
  defmacro refute_has_matching_include(conn, function) do
    quote do
      with %{"included" => included} when is_list(included) <- unquote(conn).resp_body do
        refute Enum.any?(included, fn included ->
                 unquote(function).(included)
               end)
      end

      unquote(conn)
    end
  end

  @doc false
  defmacro assert_equal_links(conn, expected_links) do
    quote bind_quoted: [expected_links: expected_links, conn: conn] do
      %{"links" => resp_links} = conn.resp_body
      assert Enum.sort(Map.keys(resp_links)) == Enum.sort(Map.keys(expected_links))

      for {key, value} <- expected_links do
        assert AshJsonApi.Test.uri_with_query(value) ==
                 AshJsonApi.Test.uri_with_query(resp_links[key]),
               "expected #{key} link to be #{resp_links[key]}, got: #{value}"
      end

      conn
    end
  end

  @doc false
  def uri_with_query(nil), do: nil

  def uri_with_query(value) do
    value
    |> URI.parse()
    |> Map.update!(:query, &URI.decode_query(&1 || %{}))
  end

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

  defp maybe_set_endpoint(conn, opts) do
    if endpoint = opts[:phoenix_endpoint] do
      put_private(conn, :phoenix_endpoint, endpoint)
    else
      conn
    end
  end

  defp set_context_opts(conn, opts) do
    conn
    |> Ash.PlugHelpers.set_actor(opts[:actor])
    |> Ash.PlugHelpers.set_tenant(opts[:tenant])
  end

  defp set_req_headers(conn, opts) do
    opts[:headers]
    |> Kernel.||([])
    |> Enum.reduce(conn, fn {header, value}, conn ->
      Plug.Conn.put_req_header(conn, to_string(header), to_string(value))
    end)
  end

  defp call_router(conn, domain, opts) do
    router = opts[:router] || AshJsonApi.Domain.Info.router(domain)

    router.call(conn, router.init([]))
  end
end
