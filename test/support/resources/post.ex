defmodule AshJsonApi.Test.Resources.Post do
  use Ash.Resource, name: "posts", type: "post"
  use AshJsonApi
  use Ash.DataLayer.Ets, private?: true

  json_api do
    routes do
      get(:default)
      index(:default)
    end

    fields [:name]
  end

  actions do
    defaults([:read, :create],
      rules: [allow(:static, result: true)]
    )
  end

  attributes do
    attribute(:name, :string)
  end
end
