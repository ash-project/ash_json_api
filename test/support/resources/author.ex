# defmodule AshJsonApi.Test.Resources.Author do
#   use Ash.Resource, name: "authors", type: "author"
#   use AshJsonApi
#   use Ash.DataLayer.Ets, private?: true

#   json_api do
#     routes do
#       get(:default)
#       index(:default)
#     end

#     fields [:name]
#   end

#   actions do
# read(:default,
# rules: [
#   allow(:static, result: true)
# ]
# )

# create(:default,
# rules: [
#   allow(:static, result: true)
# ]
# )
#   end

#   attributes do
#     attribute(:name, :string)
#   end
# end
