spark_locals_without_parens = [
  authorize?: 1,
  base: 1,
  default_fields: 1,
  delete: 1,
  delete: 2,
  delete_from_relationship: 1,
  delete_from_relationship: 2,
  delimiter: 1,
  get: 1,
  get: 2,
  includes: 1,
  index: 1,
  index: 2,
  keys: 1,
  log_errors?: 1,
  paginate?: 1,
  patch: 1,
  patch: 2,
  patch_relationship: 1,
  patch_relationship: 2,
  post: 1,
  post: 2,
  post_to_relationship: 1,
  post_to_relationship: 2,
  prefix: 1,
  primary?: 1,
  read_action: 1,
  related: 2,
  related: 3,
  relationship: 2,
  relationship: 3,
  relationship_arguments: 1,
  route: 1,
  router: 1,
  serve_schema?: 1,
  type: 1,
  upsert?: 1,
  upsert_identity: 1
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: spark_locals_without_parens,
  export: [
    locals_without_parens: spark_locals_without_parens
  ]
]
