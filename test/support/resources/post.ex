# defmodule AshJsonApi.Test.Resources.Post do
#   use Ash.Resource, name: "posts", type: "post"
#   use AshJsonApi
#   use Ash.DataLayer.Ets, private?: true

#   json_api do
#     routes do
#       get(:default)
#       index(:default)
#     end

#     fields [:name]
#     # relationship_routes :author
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

#   relationships do
#     belongs_to(:author, AshJsonApi.Test.Resources.Author)
#     has_many(:comments, AshJsonApi.Test.Resources.Comment)
#   end
# end
