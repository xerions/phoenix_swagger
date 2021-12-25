# Used by "mix format"

locals_without_parens = [
  delete: 1,
  deprecated: 1,
  description: 1,
  get: 1,
  head: 1,
  nest: 1,
  operation_id: 1,
  options: 1,
  paging: 1,
  parameters: 1,
  parameters: 5,
  patch: 1,
  post: 1,
  put: 1,
  response: 2,
  response: 3,
  response: 4,
  security: 1,
  summary: 1,
  tag: 1
]

[
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: locals_without_parens,
  export: [locals_without_parens: locals_without_parens]
]
