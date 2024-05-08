# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](Https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v1.0.0](https://github.com/ash-project/ash_json_api/compare/v1.0.0...v0.34.2)

This changelog has been restarted. See `/documentation/0.x-CHANGELOG.md` for previous changelogs.

### Breaking Changes:

- [AshJsonApi.Resource] relationship routes now depend on the action taking an argument with the same name as the relationship. See the upgrade for more.

- [AshJsonApi.ToJsonApiError] Introduced `AshJsonApi.ToJsonApiError` to convert errors to JSON API errors. This brings it more in line with other Ash extensions.

### Improvements:

- [AshJsonApi.Resource] create/update/destroy actions now use bulk operations
- [AshJsonApi.Router] router is now a dynamic hand-written router. This prevents compile time dependencies.
- [AshJsonApi.Error] honor path when building source pointers
