# Require Type on Create (Issue #164)

This document describes the JSON:API spec-compliance change for create requests (GitHub issue #164): what the issue is, what was implemented, and every file that was added or changed.

---

## The Issue Explained

### Plain terms

When a client **creates** a resource with a POST request, the JSON:API spec says the body must include a **`type`** field inside the `data` object. So a valid create body looks like:

```json
{
  "data": {
    "type": "artists",
    "attributes": { "name": "...", "biography": "..." }
  }
}
```

The spec says the resource object (the thing inside `"data"`) **must** include a `type` member. It’s required, not optional.

**What AshJsonApi did before:** If the client sent `type`, it was validated (wrong or empty value → error). If the client **omitted** `type` entirely, AshJsonApi still created the resource and returned 201. So the API was not fully spec-compliant.

**Why it still “worked”:** The server already knows the type from the URL (e.g. `POST /artists` → type is “artists”). Omitting `type` didn’t change what got created; the gap is about **spec compliance**, not behavior.

**The fix:** Reject create requests when `data` has no `type` (or it’s empty), and return a clear 400 error. To avoid breaking existing clients, this is **opt-in** per domain (`require_type_on_create?`). When the option is `true`, the server enforces the spec; when `false` (default), behavior is unchanged.

---

### Technical terms

- **JSON:API (Creating Resources):** The request MUST include a single resource object as primary data. The resource object MUST contain at least a **`type`** member.  
  Ref: [jsonapi.org/format/#crud-creating](https://jsonapi.org/format/#crud-creating)

- **AshJsonApi before:** Validated `type` when present (e.g. via schema `const`). Did **not** require `type` to be present; creation succeeded when `type` was omitted.

- **Gap:** Non-compliance with the MUST requirement for `type` on create.

- **Fix:** Add a domain-level opt-in, `require_type_on_create?` (default `false`). When `true`, before processing a POST create request, the pipeline checks that `body["data"]` is a map and that `body["data"]["type"]` is present and non-empty. If not, the request is rejected with a 400 and a single JSON:API error: `code: "missing_type"`, `title: "Invalid resource object"`, `detail: "The resource object MUST contain at least a type member."`, `source_pointer: "/data"`.

- **Design:** Opt-in until a future major version, when it may default to `true` (per maintainer direction on issue #164).

---

## Files Added

### 1. `lib/ash_json_api/error/missing_type_on_create.ex`

**Purpose:** Defines the exception and its JSON:API representation when a create request is rejected for missing `type`.

**What it does:**

- **Module:** `AshJsonApi.Error.MissingTypeOnCreate`. Uses `Splode.Error` with `class: :invalid` and no extra fields.
- **`message/1`:** Returns the spec wording: `"The resource object MUST contain at least a type member."`
- **`ToJsonApiError` implementation:** Converts the exception into a single `%AshJsonApi.Error{}` with:
  - `status_code: 400`
  - `code: "missing_type"`
  - `title: "Invalid resource object"`
  - `detail:` same message as above
  - `source_pointer: "/data"` (so clients know the problem is in the request body’s `data` object)
  - `id:` new UUID, `meta: %{}`

This is the only new runtime module for the feature; the request pipeline adds this error when the opt-in is enabled and `data.type` is missing or empty.

---

### 2. `test/acceptance/require_type_on_create_test.exs`

**Purpose:** Acceptance tests for the require-type-on-create behavior.

**What it does:**

- Defines test resources and two domains: one **without** `require_type_on_create?` (default) and one **with** `require_type_on_create? true`.
- **Default (opt-in off):** Asserts that POST create **without** `type` in `data` still succeeds (backwards compatibility).
- **Strict (opt-in on):** Asserts that:
  - POST create **without** `type` returns 400 and a JSON:API error with `code: "missing_type"`, `source_pointer: "/data"`.
  - POST create **with** valid `type` succeeds.
  - POST create with empty string `type` is rejected (400, same error shape).
- Covers both “default domain” and “strict domain” so the opt-in and the error shape are both validated.

---

## Files Changed

### 1. `lib/ash_json_api/domain/domain.ex`

**Why:** Expose the opt-in so domains can turn on strict JSON:API behavior for create.

**Edit:**

- In the `json_api` section schema (inside the `schema: [...]` list), **add** one new option:

```elixir
require_type_on_create?: [
  type: :boolean,
  default: false,
  doc:
    "When true, POST create requests MUST include type in data. Default false for backwards compatibility; in a future major version may default to true."
]
```

**What this does:** Allows users to set `require_type_on_create? true` in their domain’s `json_api do ... end` block. Default is `false`, so existing apps are unchanged. The doc explains the default and the possible future major-version change.

---

### 2. `lib/ash_json_api/domain/info.ex`

**Why:** The request pipeline needs to read the domain’s opt-in at runtime.

**Edit:**

- **Add** a new public function:

```elixir
def require_type_on_create?(domain) do
  Extension.get_opt(domain, [:json_api], :require_type_on_create?, false, true)
end
```

**What this does:** Returns the value of `require_type_on_create?` for the given domain (default `false` if not set). Same pattern as other domain options in this module (e.g. `include_nil_values?/1`). The request step uses this to decide whether to enforce the presence of `data.type` on POST create.

---

### 3. `lib/ash_json_api/request.ex`

**Why:** Enforce “data must have type” on create when the domain has the opt-in enabled, and return the dedicated error.

**Edits:**

1. **Alias (error list):** Add `MissingTypeOnCreate` to the `alias AshJsonApi.Error.{ ... }` list so the new error module can be used when adding a validation error.

2. **Pipeline:** In the `from/2` pipeline, after `validate_body()`, add:
   ```elixir
   |> validate_require_type_on_create()
   ```
   So every request runs this step; the step only does something for POST create when the opt-in is on.

3. **New private function (main logic):**  
   - **Clause 1** – When the request is a POST, the body has `"data"` as a map, and the domain has `require_type_on_create?` true:
     - Read `data["type"]`.
     - If it is `nil` or `""`, add `MissingTypeOnCreate` to the request errors (via `add_error(..., MissingTypeOnCreate.exception([]), request.route.type)`).
     - Otherwise leave the request unchanged.
   - **Clause 2** – Fallback: `defp validate_require_type_on_create(request), do: request` for all other requests (GET, PATCH, DELETE, or when body doesn’t have a map `data`).

**What this does:** Ensures that when the domain opts in, any POST create request whose `data` object is missing `type` or has an empty `type` is rejected before further processing, with a single, spec-aligned JSON:API error produced by `MissingTypeOnCreate`.

---

## Summary Table

| File | Added or changed | What it does |
|------|------------------|--------------|
| `lib/ash_json_api/error/missing_type_on_create.ex` | **Added** | Defines the “missing type” exception and its JSON:API error (400, `missing_type`, `source_pointer: "/data"`). |
| `test/acceptance/require_type_on_create_test.exs` | **Added** | Acceptance tests: default (no type still works) and strict (no type → 400, with type → success). |
| `lib/ash_json_api/domain/domain.ex` | **Changed** | Adds `require_type_on_create?` option to the `json_api` DSL (boolean, default `false`). |
| `lib/ash_json_api/domain/info.ex` | **Changed** | Adds `require_type_on_create?(domain)` to read the option at runtime. |
| `lib/ash_json_api/request.ex` | **Changed** | Adds `validate_require_type_on_create` to the pipeline and implements the check for POST create when opt-in is true; uses `MissingTypeOnCreate` when `data.type` is missing or empty. |

---

## How to enable

In your domain:

```elixir
json_api do
  require_type_on_create? true   # require `type` in POST create body
  # ...
end
```

With this set, any create request whose `data` object omits `type` (or has empty `type`) receives a 400 response and one error object with `code: "missing_type"` and `source_pointer: "/data"`.
