defmodule AshJsonApi.Api do
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @extensions AshJsonApi.Api
      @prefix nil
      @host nil
      @serve_schema false
      @authorize Keyword.get(opts, :authorize?, true)

      require AshJsonApi.Api
      import AshJsonApi.Api, only: [json_api: 1]
    end
  end

  defmacro json_api(do: block) do
    quote do
      import AshJsonApi.Api, only: [host: 1, serve_schema: 1, prefix: 1]
      unquote(block)
      import AshJsonApi.Api, only: []
    end
  end

  defmacro prefix(prefix) do
    quote do
      @prefix unquote(prefix)
    end
  end

  defmacro host(host) do
    quote do
      @host unquote(host)
    end
  end

  defmacro serve_schema(boolean) do
    quote do
      @serve_schema unquote(boolean)
    end
  end

  def before_compile_hook(_env) do
    quote do
      use AshJsonApi.Api.Router,
        api: __MODULE__,
        resources: @resources,
        prefix: @prefix,
        serve_schema: @serve_schema

      def router do
        Module.concat(__MODULE__, Router)
      end

      def prefix do
        @prefix
      end

      def authorize? do
        @authorize
      end

      def host do
        @host
      end

      def serve_schema do
        @serve_schema
      end
    end
  end
end
