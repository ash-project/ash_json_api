# Require Type on Create (Issue #164)

JSON:API requires that the resource object in a create (POST) request include a `type` member inside the `data` object, but AshJsonApi previously allowed creates without `data.type`, relying on the URL-implied type and thus violating the spec. The fix adds a domain-level opt-in `require_type_on_create?` (default `false`) so that, when enabled, POST create requests without a non-empty `data.type` are rejected with a 400 JSON:API error (`code: "missing_type"`, `title: "Invalid resource object"`, `detail: "The resource object MUST contain at least a type member."`, `source_pointer: "/data"`), while existing behavior is preserved when the option is `false`.

