# SPDX-FileCopyrightText: 2019 ash_json_api contributors <https://github.com/ash-project/ash_json_api/graphs/contributors>
#
# SPDX-License-Identifier: MIT

defmodule AshJsonApi.Plug.Parser do
  @moduledoc """
  Extracts ash multipart request body.

  For use with `Plug.Parsers`, as in the example below.

  ## Examples

  Should be used with `Plug.Parsers`:

      plug Plug.Parsers,
        parsers: [:urlencoded, :multipart, :json, #{inspect(__MODULE__)}],
        pass: ["*/*"],
        json_decoder: Jason

  ## Protocol

  To use files in your request, send a
  [multipart](https://developer.mozilla.org/en-US/docs/Web/HTTP/Basics_of_HTTP/MIME_types#multipart)
  with the content type `multipart/x.ash+form-data`. The request MUST
  contain a JSON object with the key `data` and the value of the object you want
  to send.

  The request MAY contain other keys with the value of the file you want to
  send. The parser will walk through all of the `data` JSON and replace each
  string equal to a part name with the content of the part. This means that if
  you have a part named `users_csv` and a key in the `data` JSON object with the
  value `users_csv`, the parser will replace the string with the content of the
  part.

  > #### Conflicting Part names {:.warning}
  >
  > Ensure that each part name is unique and does not naturally occur inside as
  > a string in the `data` JSON object. If a part name is found in the `data`
  > JSON object, the parser will replace it with the content of the part.
  >
  > It is recommended to use a unique value like a UUID as the part name.

  ## Example HTTP Message

  ```
  POST /action
  Host: example.com
  Content-Length: 2740
  Content-Type: multipart/x.ash+form-data; boundary=abcde12345
  --abcde12345
  Content-Disposition: form-data; name="data"
  Content-Type: application/vnd.api+json

  {"users": "users_csv", "meatdata": "metadata_json"}
  --abcde12345
  Content-Disposition: form-data; name="users_csv"; filename="users.csv"
  Content-Type: text/csv

  [file content goes here]
  --abcde12345
  Content-Disposition: form-data; name="metadata_json"; filename="metadata.json"
  Content-Type: application/json

  [file content goes there]
  --abcde12345--
  ```
  """

  alias Plug.Parsers.JSON
  alias Plug.Parsers.MULTIPART

  @behaviour Plug.Parsers

  @typep json_node() ::
           integer()
           | binary()
           | float()
           | boolean()
           | nil
           | [json_node()]
           | %{optional(String.t()) => json_node()}
  @typep part_acc() :: {:ok, json_node(), Plug.Conn.Query.decoder(), Plug.Conn.t()}

  @doc false
  @impl Plug.Parsers
  def init(opts) do
    json_opts =
      opts
      |> Keyword.put_new(:body_reader, {__MODULE__, :read_part, []})
      |> JSON.init()

    opts
    |> Keyword.put_new(:multipart_to_params, {__MODULE__, :multipart_to_params, [json_opts]})
    |> MULTIPART.init()
  end

  @doc false
  @impl Plug.Parsers
  def parse(conn, "multipart", "x.ash+form-data", headers, opts),
    do:
      MULTIPART.parse(
        conn,
        "multipart",
        "mixed",
        headers,
        opts
      )

  def parse(conn, _type, _subtype, _headers, _opts), do: {:next, conn}

  @doc false
  def read_part(%Plug.Conn{private: %{__MODULE__ => part}} = conn, _opts),
    do: {:ok, part, %Plug.Conn{conn | private: Map.delete(conn.private, __MODULE__)}}

  @doc false
  def multipart_to_params(parts, conn, json_opts) do
    parts
    |> Enum.reverse()
    |> Enum.reduce_while(
      {:ok, %{}, Plug.Conn.Query.decode_init(), conn},
      &reduce_part(&1, &2, json_opts)
    )
    |> case do
      {:ok, data, acc, conn} ->
        {:ok, %{"data" => integrate_uploads(data, Plug.Conn.Query.decode_done(acc))}, conn}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec reduce_part(
          part :: {name :: String.t(), headers :: Plug.Conn.headers(), body :: Plug.Upload.t()},
          part_acc :: part_acc(),
          json_opts :: term(),
          force_generic :: boolean()
        ) :: {:cont, part_acc()} | {:halt, {:error, term()}}
  defp reduce_part(part, acc, json_opts, force_generic \\ false)

  # sobelow_skip ["Traversal.FileModule"]
  defp reduce_part(
         {"data", part_headers, %Plug.Upload{path: path} = body},
         {:ok, data, acc, conn},
         json_opts,
         false
       )
       when data == %{} do
    with {:ok, type, subtype, _params} <- extract_part_type(part_headers),
         {:ok, content} <- File.read(path),
         {:ok, data, conn} <-
           JSON.parse(
             %Plug.Conn{conn | private: Map.put(conn.private, __MODULE__, content)},
             type,
             subtype,
             part_headers,
             json_opts
           ) do
      {:cont, {:ok, data, acc, conn}}
    else
      {:error, :invalid_mime_type} ->
        reduce_part({"data", part_headers, body}, {:ok, data, acc, conn}, json_opts, true)

      {:error, :no_content_type} ->
        reduce_part({"data", part_headers, body}, {:ok, data, acc, conn}, json_opts, true)

      {:next, conn} ->
        reduce_part({"data", part_headers, body}, {:ok, data, acc, conn}, json_opts, true)

      {:error, reason} ->
        {:halt, {:error, reason}}
    end
  end

  defp reduce_part({name, _headers, body}, {:ok, data, acc, conn}, _json_opts, _force_generic),
    do: {:cont, {:ok, data, Plug.Conn.Query.decode_each({name, body}, acc), conn}}

  @spec extract_part_type(part_headers :: Plug.Conn.headers()) ::
          {:ok, type :: binary(), subtype :: binary(), params :: Plug.Conn.Utils.params()}
          | {:error, :invalid_mime_type | :no_content_type}
  defp extract_part_type(part_headers) do
    case List.keyfind(part_headers, "content-type", 0) do
      {"content-type", content_type} ->
        case Plug.Conn.Utils.content_type(content_type) do
          {:ok, type, subtype, params} -> {:ok, type, subtype, params}
          :error -> {:error, :invalid_mime_type}
        end

      _ ->
        {:error, :no_content_type}
    end
  end

  @spec integrate_uploads(
          node :: json_node(),
          uploads :: %{optional(String.t()) => Plug.Upload.t()}
        ) :: json_node()
  defp integrate_uploads(node, uploads) when is_map(node),
    do: Map.new(node, fn {k, v} -> {k, integrate_uploads(v, uploads)} end)

  defp integrate_uploads(node, uploads) when is_list(node),
    do: Enum.map(node, &integrate_uploads(&1, uploads))

  defp integrate_uploads(node, uploads) when is_binary(node), do: Map.get(uploads, node, node)
  defp integrate_uploads(node, _uploads), do: node
end
