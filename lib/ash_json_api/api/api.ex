defmodule AshJsonApi.Api do
  defmacro __using__(opts) do
    quote bind_quoted: [prefix: opts[:prefix]], location: :keep do
      @mix_ins AshJsonApi.Api
      @prefix prefix
      require AshJsonApi.Api
    end
  end

  def before_compile_hook(_env) do
    quote do
      use AshJsonApi.Api.Router, api: __MODULE__, resources: @resources, prefix: @prefix

      def router() do
        Module.concat(__MODULE__, Router)
      end
    end
  end
end
