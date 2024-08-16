# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

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
