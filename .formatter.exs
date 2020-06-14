locals_without_parens = [
  get: 1,
  get: 2,
  index: 1,
  index: 2,
  post: 1,
  patch: 2,
  post: 1,
  post: 2,
  delete: 1,
  delete: 2,
  fields: 1,
  include: 1,
  relationship: 1,
  relationship: 2,
  relationship: 3,
  related: 1,
  related: 2,
  related: 3,
  relationship_routes: 2,
  relationship_routes: 1,
  prefix: 1,
  serve_schema: 1,
  host: 1
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: locals_without_parens,
  export: [
    locals_without_parens: locals_without_parens
  ]
]
