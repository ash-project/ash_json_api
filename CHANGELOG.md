# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v1.4.24](https://github.com/ash-project/ash_json_api/compare/v1.4.23...v1.4.24) (2025-04-09)




### Bug Fixes:

* properly determine aggregate filter types

* attribute descriptions may not be present

### Improvements:

* Support UUIDv7, Time type in AshJsonApi.OpenApi (#322)

* Refactor filter_type/2 of OpenAPI with raw_filter_type/2 (#319)

* Check :description also in AshJsonApi.OpenApi.unwrap_any_of/1 (#318)

* Add description in filter_type/2, raw_filter_type/2 (#315)

* Preserve description with anyOf (#314)

* Impl serializing with load (#313)

* Add description of attributes in OpenAPI.resource_write_attribute_type/3 (#311)

## [v1.4.23](https://github.com/ash-project/ash_json_api/compare/v1.4.22...v1.4.23) (2025-03-25)




### Bug Fixes:

* move additionalProperties into schema, not properties

### Improvements:

* support more types in OpenApi (#304)

## [v1.4.22](https://github.com/ash-project/ash_json_api/compare/v1.4.21...v1.4.22) (2025-03-19)




### Bug Fixes:

* remove accidentally commited future code

### Improvements:

* handle NewTypes in write attributes

* add `additionalProperties: false` where possible

## [v1.4.21](https://github.com/ash-project/ash_json_api/compare/v1.4.20...v1.4.21) (2025-03-18)




### Bug Fixes:

* properly handle nested `anyOf` statements in open api

* show predicate functions in open api spec

## [v1.4.20](https://github.com/ash-project/ash_json_api/compare/v1.4.19...v1.4.20) (2025-03-11)




### Bug Fixes:

* display primary keys for embedded resources

## [v1.4.19](https://github.com/ash-project/ash_json_api/compare/v1.4.18...v1.4.19) (2025-02-11)




### Bug Fixes:

* Use debug log level for errors by default (#289)

* ensure that update actions don't require all inputs

* apply default_fields to included relationships

### Improvements:

* add calculation inputs to openapi filter spec

* Include source pointer in the debug logs

## [v1.4.18](https://github.com/ash-project/ash_json_api/compare/v1.4.17...v1.4.18) (2025-01-29)




### Improvements:

* On igniter install modify project aliases with expanded routes task (#282)

* Add task for printing ash json routes (#281)

## [v1.4.17](https://github.com/ash-project/ash_json_api/compare/v1.4.16...v1.4.17) (2025-01-27)




### Bug Fixes:

* don't display calculations just because they are loaded

* use 404 for `Ash.Error.Query.NotFound`

* properly fall back to `filter` or nothing for built-in not Found

* required attributes being marked as nullable in OpenAPI output (#269)

## [v1.4.16](https://github.com/ash-project/ash_json_api/compare/v1.4.15...v1.4.16) (2024-12-23)




### Improvements:

* make testing helpers public and document them

* deprecate the DSL router configuration

## [v1.4.15](https://github.com/ash-project/ash_json_api/compare/v1.4.14...v1.4.15) (2024-12-20)




### Bug Fixes:

* only use route's fields on top level records

* nested boolean filters accept a list of filters, not a single filter

* encode primary key always when encoding resources as values

### Improvements:

* make igniter optional

## [v1.4.14](https://github.com/ash-project/ash_json_api/compare/v1.4.13...v1.4.14) (2024-11-24)




### Bug Fixes:

* add opts to all Ash.load calls (#260)

## [v1.4.13](https://github.com/ash-project/ash_json_api/compare/v1.4.12...v1.4.13) (2024-11-04)




### Bug Fixes:

* mark filters as deepObject

* support `null` input for non-required attributes

### Improvements:

* fix relationship representation & descriptions in open api schema

* add `sort_included` query parameter

* add sort_included query parameter

* accept arbitrary filters (by making it a stupid text field)

## [v1.4.12](https://github.com/ash-project/ash_json_api/compare/v1.4.11...v1.4.12) (2024-10-21)




### Bug Fixes:

* hide private arguments in open api (#247)

## [v1.4.11](https://github.com/ash-project/ash_json_api/compare/v1.4.10...v1.4.11) (2024-10-14)




### Improvements:

* add type handler for NaiveDatetime

## [v1.4.10](https://github.com/ash-project/ash_json_api/compare/v1.4.9...v1.4.10) (2024-10-10)




### Improvements:

* set status only if it hasn't already been set

* better examples for `fields` parameter

## [v1.4.9](https://github.com/ash-project/ash_json_api/compare/v1.4.8...v1.4.9) (2024-09-27)




### Bug Fixes:

* properly strip double slashes from base_route prefixes

* properly render post to relationship and friends in open api spec

* support keyset & offset pagination when mixed in open api schema

### Improvements:

* support providing the open api schema as a file

## [v1.4.8](https://github.com/ash-project/ash_json_api/compare/v1.4.7...v1.4.8) (2024-09-16)




### Bug Fixes:

* don't access `message` key of `InvalidKeyset` errors

### Improvements:

* upgrade to latest igniter functions and version

## [v1.4.7](https://github.com/ash-project/ash_json_api/compare/v1.4.6...v1.4.7) (2024-09-04)




### Bug Fixes:

* decode path parameters automatically

## [v1.4.6](https://github.com/ash-project/ash_json_api/compare/v1.4.5...v1.4.6) (2024-08-26)




### Bug Fixes:

* don't intercept typed structs

* properly check for domain inclusion in json api router when installing

### Improvements:

* support new struct types w/ constraints

## [v1.4.5](https://github.com/ash-project/ash_json_api/compare/v1.4.4...v1.4.5) (2024-08-20)




### Bug Fixes:

* properly discover all necessary filter schemas

### Improvements:

* optimize post-operation field loading logic

* don't show tags for resources w/o routes in schema

## [v1.4.4](https://github.com/ash-project/ash_json_api/compare/v1.4.3...v1.4.4) (2024-08-16)




### Improvements:

* support nested `base_route`s

## [v1.4.3](https://github.com/ash-project/ash_json_api/compare/v1.4.2...v1.4.3) (2024-08-08)




### Improvements:

* new `AshJsonApi.Type` behaviour, and support returning regular maps

## [v1.4.2](https://github.com/ash-project/ash_json_api/compare/v1.4.1...v1.4.2) (2024-08-08)




### Bug Fixes:

* use a list when calling `Module.concat`

## [v1.4.1](https://github.com/ash-project/ash_json_api/compare/v1.4.0...v1.4.1) (2024-07-30)




### Improvements:

* properly install domain with `Module.concat` in AshJsonApi router

* include multipart parser in installer

## [v1.4.0](https://github.com/ash-project/ash_json_api/compare/v1.3.8...v1.4.0) (2024-07-30)

### Features:

- [`Ash.Type.File`] Ash.Type.File support (#214)

See `AshJsonApi.Plug.Parser` for usage information.

### Bug Fixes:

- [attributes] reject allow_nil_input fields in required_write_attributes (#219)

- [Open API] properly document query_params from generic routes in open api spec

- [Open API] only include referenced resource types in definitions

- [Open API] properly spec (and test the spec) for actions that return resources

## [v1.3.8](https://github.com/ash-project/ash_json_api/compare/v1.3.7...v1.3.8) (2024-07-22)

### Bug Fixes:

- [`AshJsonApi.Router`] don't double escape `modify_open_api`

### Improvements:

- [`AshJsonApi.Router`] automatically infer the `prefix` instead of relying on configuration

- [`mix ash.patch.extend`] add `AshJsonApi` extender

- [`mix ash_json_api.install`] add installer for AshJsonApi

## [v1.3.7](https://github.com/ash-project/ash_json_api/compare/v1.3.6...v1.3.7) (2024-07-15)

### Bug Fixes:

- [open api] escape `modify_open_api_schema` option since it can be a 3/tuple

- [errors] handle unknown errors in `log_errors/2`

- [serialization] relationship resource identifiers don't need to check the `id` type

- [serialization] properly reference related record in linkage

- [serialization] ensure id is always coming back as a string

## [v1.3.6](https://github.com/ash-project/ash_json_api/compare/v1.3.5...v1.3.6) (2024-07-08)

### Bug Fixes:

- [open api] properly match enum types on input/output

- [errors] Avoid raising the condition converting the regex to string. (#204)

### Improvements:

- [content type negotation] honor `allow_all_media_type_params?` in `content-type` as well

## [v1.3.5](https://github.com/ash-project/ash_json_api/compare/v1.3.4...v1.3.5) (2024-07-06)

### Bug Fixes:

- [bugfix] use `conn.private`, not `conn[:private]`

## [v1.3.4](https://github.com/ash-project/ash_json_api/compare/v1.3.3...v1.3.4) (2024-07-05)

### Bug Fixes:

- [errors] add leading slash to JSON pointer in schema errors (#199)

- [open api] avoid failing openapi generation for non existing resource actions (#198)

## [v1.3.3](https://github.com/ash-project/ash_json_api/compare/v1.3.2...v1.3.3) (2024-07-04)

### Bug Fixes:

- [serialization] ensure generic action bodies, both in & out are serialized properly

- [open api] properly fetch nested types

- [open api] show embedded types when used with `:struct`

- [open api] ensure `action.require_attributes` is stringified in json schema

- [fields parameter] honor resource-level default_fields

## [v1.3.2](https://github.com/ash-project/ash_json_api/compare/v1.3.1...v1.3.2) (2024-07-02)

### Bug Fixes:

- [routes] ensure that context is threaded through for all actions

- [open api] properly require `success` in return-less actions

- [open api] typo when checking for resource's derive_filter? flag

- [open api] not all accepted attributes have to be public

- [open api] fix sort regex to be a valid regex

- [open api] don't use `anyOf` for nullability

- [open api] don't generate bodies for delete requests

- [open api] use `Enum.uniq` when uwnrapping any_of types

- [open api] detect all cases where a filter must be generated

### Improvements:

- [open api] use empty example for filter

- [routes] support for query parameters using `query_params` route option

## [v1.3.1](https://github.com/ash-project/ash_json_api/compare/v1.3.0...v1.3.1) (2024-07-01)

### Bug Fixes:

- [open api] use strings for enum values

- [open api] use `strings` for includes/sort properly, add regex for sort

## [v1.3.0](https://github.com/ash-project/ash_json_api/compare/v1.2.2...v1.3.0) (2024-06-28)

### Features:

- [calculations] add support for calculation inputs via field_inputs query param (#187)

- [routes] support generic actions with no returns in routes

- [routes] support `modify_conn/4`

- [routes] support `:read` actions in `:post` request

- [routes] generic action support for all basic route types

- [routes] new `route/3` type for arbitrary generic actions

- [AshJsonApi.Resource] support `derive_filter?` on both resource and route level

- [AshJsonApi.Resource] support `derive_sort?` on both resource and route level

### Improvements:

- [OpenApi] implement `Ash.Type.Map` json schema

- [OpenApi] support unions in schemas

- [OpenApi] use "any object" type for filter in json schema

- [OpenApi] fully specify filter in open api schema

- [OpenApi] show all sortable fields in json schema

- [OpenApi] Use resource descriptions in generated schema files if present (#184)

- [OpenApi] show embeds in json schema and openapi

- [errors] Add defimpl for NoSuchInput error (#181)

## [v1.2.2](https://github.com/ash-project/ash_json_api/compare/v1.2.1...v1.2.2) (2024-06-19)

### Bug Fixes:

- [include] properly still perform includes on record fetched from path

### Improvements:

- [OpenApi] newtype/enum support for json_schema as well

- [OpenApi] render enums as enums in open api

## [v1.2.1](https://github.com/ash-project/ash_json_api/compare/v1.2.0...v1.2.1) (2024-06-18)

### Bug Fixes:

- [routes] don't raise error including on get related endpoints

- [routes] validate relationships from routes at compile time

- [errors] don't show exceptions if `show_raised_errors?` is `false`

- [errors] add missing fields from `InvalidField`

- [OpenApi] don't expose `action.name` over api docs

- [AshJsonApi.Domain] resource comes from the route on domains

### Improvements:

- [routes] support `name` on `routes`, use in description and operationId

- [AshJsonApi.Resource] verify includes list at compile time

- [AshJsonApi.Domain] allow setting a `resource` second option on domain's `base_route` entity

## [v1.2.0](https://github.com/ash-project/ash_json_api/compare/v1.1.2...v1.2.0) (2024-06-11)

### Features:

- [AshJsonApi.Domain] add `base_route` constructor to domain router

### Bug Fixes:

- [AshJsonApi.Resource] properly reflect that `default: false` makes a non required attribute

- [AshJsonApi.Resource] non-public attributes can be accepted and required in 3.0

- [AshJsonApi.Resource] support `require_attributes` in json schema

- [AshJsonApi.Resource] ensure that resource-level default_fields are honored

### Improvements:

- [attributes] non-public attributes can be accepted in 3.0

## [v1.1.2](https://github.com/ash-project/ash_json_api/compare/v1.1.1...v1.1.2) (2024-06-05)

### Bug Fixes:

- [includes] ensure we don't drop includes (as a result of deduplicating them)

## [v1.1.1](https://github.com/ash-project/ash_json_api/compare/v1.1.0...v1.1.1) (2024-06-05)

### Bug Fixes:

- [includes] deduplicate includes list while building it

### Improvements:

- [metadata] add ability to supply custom route metadata (#152)

## [v1.1.0](https://github.com/ash-project/ash_json_api/compare/v1.0.0...v1.1.0) (2024-05-24)

### Features:

- [AshJsonApi.Domain] support routes defined on the domain

## [v1.0.0](https://github.com/ash-project/ash_json_api/compare/v1.0.0...v0.34.2)

This changelog has been restarted. See `/documentation/0.x-CHANGELOG.md` for previous changelogs.

### Breaking Changes:

- [AshJsonApi.Resource] relationship routes now depend on the action taking an argument with the same name as the relationship. See the upgrade for more.

- [AshJsonApi.ToJsonApiError] Introduced `AshJsonApi.ToJsonApiError` to convert errors to JSON API errors. This brings it more in line with other Ash extensions.

### Improvements:

- [AshJsonApi.Resource] create/update/destroy actions now use bulk operations
- [AshJsonApi.Router] router is now a dynamic hand-written router. This prevents compile time dependencies.
- [AshJsonApi.Error] honor path when building source pointers
