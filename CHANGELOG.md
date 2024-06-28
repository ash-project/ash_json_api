# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

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
